"""Export and verify the October 2026 demo through the running reporting API.

Reads local administrator credentials without printing them. Does not close
payroll, send email, or change attendance.
"""
import argparse
import json
import sys
from datetime import datetime, timezone, timedelta
from decimal import Decimal, ROUND_HALF_UP
from pathlib import Path
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / '.local-data/excel-test-tools'))
from openpyxl import Workbook, load_workbook
from openpyxl.styles import Font, PatternFill, Alignment
from openpyxl.worksheet.table import Table, TableStyleInfo
from openpyxl.utils import get_column_letter


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--api-base-url', default='http://127.0.0.1:5080')
    args = parser.parse_args()
    base = args.api_base_url.rstrip('/')
    raw = json.loads((ROOT / '.local-data/account-credentials.json').read_text(encoding='utf-8-sig'))
    accounts = []
    for item in raw if isinstance(raw, list) else [raw]:
        accounts.extend(item.get('value', [item]))
    admin = next(a for a in accounts if a.get('Role', a.get('role')) == 'admin')
    token = None

    def api(path, body=None):
        headers = {'Content-Type': 'application/json'}
        if token:
            headers['Authorization'] = 'Bearer ' + token
        request = Request(base + '/api' + path, data=None if body is None else json.dumps(body).encode(), headers=headers)
        with urlopen(request, timeout=30) as response:
            return json.load(response)

    token = api('/auth/login', {'email': admin.get('Email', admin.get('email')), 'password': admin.get('Password', admin.get('password'))})['token']
    report = api('/reports?start=2026-10-01&end=2026-11-01')
    expected = {
        'NV01': (22, 10560, 0, 0),
        'NV02': (21, 9960, 4, 2),
        'NV03': (20, 9480, 2, 1),
        'NV04': (22, 10485, 3, 3),
    }
    rows = sorted([r for r in report if r['code'] in expected], key=lambda r: r['code'])
    assert len(rows) == 4, 'Expected four employees in the reporting API'
    for row in rows:
        actual = (row['days_worked'], Decimal(str(row['worked_minutes'])), row['late_days'], row['early_days'])
        assert actual == expected[row['code']], f"Report mismatch for {row['code']}: {actual}"
        assert row['missing_checkout'] == 0, f"Unpaired attendance for {row['code']}"
        pay = (Decimal(str(row['worked_minutes'])) / 60 * Decimal(str(row['hourly_rate']))).quantize(Decimal('1'), rounding=ROUND_HALF_UP)
        assert Decimal(str(row['gross_pay'])) == pay

    zone = timezone(timedelta(hours=7))
    ids = {r['employee_id'] for r in rows}
    events = []
    for event in api('/attendance/events'):
        at = datetime.fromisoformat(event['occurred_at'].replace('Z', '+00:00')).astimezone(zone)
        if event['employee_id'] in ids and at.year == 2026 and at.month == 10:
            assert not event['voided_at']
            assert event['flag'] == 'DEMO_OCT2026_V1 - Du lieu mau thang 10/2026'
            events.append((event, at))
    assert len(events) == 340, f'Expected 340 events, found {len(events)}'
    events.sort(key=lambda item: (item[0]['employees']['code'], item[1]))

    wb = Workbook()
    summary = wb.active
    summary.title = 'Bao cao luong'
    summary.append(['BÁO CÁO CÔNG VÀ LƯƠNG MẪU – THÁNG 10/2026'])
    summary.merge_cells('A1:I1')
    summary.append(['01/10/2026–31/10/2026 • Dữ liệu minh họa • Lương gộp dự kiến, kỳ chưa chốt'])
    summary.merge_cells('A2:I2')
    summary.append([])
    summary.append(['Mã NV', 'Họ và tên', 'Ngày công', 'Giờ công', 'Ngày trễ', 'Ngày về sớm', 'Thiếu ra', 'Đơn giá/giờ (VND)', 'Lương gộp (VND)'])
    for row in rows:
        summary.append([row['code'], row['full_name'], row['days_worked'], float(Decimal(str(row['worked_minutes'])) / 60), row['late_days'], row['early_days'], row['missing_checkout'], row['hourly_rate'], row['gross_pay']])
    summary.append(['TỔNG', '', sum(r['days_worked'] for r in rows), float(sum(Decimal(str(r['worked_minutes'])) for r in rows) / 60), sum(r['late_days'] for r in rows), sum(r['early_days'] for r in rows), 0, None, sum(r['gross_pay'] for r in rows)])
    summary.append(['Tổng ngày công là tổng người-ngày; giờ nghỉ 12:00–13:00 không tính công.'])
    summary.merge_cells('A10:I10')
    detail = wb.create_sheet('Chi tiet cham cong')
    detail.append(['Mã NV', 'Họ và tên', 'Ngày', 'Giờ Việt Nam', 'Loại lượt', 'Nguồn', 'Ghi chú', 'ID lượt'])
    for event, at in events:
        detail.append([event['employees']['code'], event['employees']['full_name'], at.date(), at.time().replace(tzinfo=None), 'Vào' if event['type'] == 'check_in' else 'Ra', event['source'], event['flag'], event['id']])
    guide = wb.create_sheet('Huong dan test')
    notes = [
        ('Phạm vi', '4 nhân viên NV01–NV04, tháng 10/2026; 85 người-ngày, 340 lượt vào/ra, tất cả là dữ liệu mẫu.'),
        ('Xem báo cáo', 'Báo cáo & lương → Tháng → bấm ngày và chọn một ngày trong tháng 10/2026 → tải lại.'),
        ('NV01', '22 ngày đủ công, 176 giờ; không trễ/về sớm.'),
        ('NV02', 'Nghỉ 09/10; trễ 15 phút ngày 05,12,19,26; về sớm 30 phút ngày 07,21.'),
        ('NV03', 'Nghỉ 02,16/10; trễ 30 phút ngày 06,20; về sớm 60 phút ngày 14.'),
        ('NV04', 'Trễ 10 phút ngày 01,15,29; về sớm 15 phút ngày 08,22,30.'),
        ('Công thức', 'Giờ công = phút các khoảng đủ vào/ra ÷ 60; lương gộp dự kiến = giờ công × đơn giá hiện tại. Chưa tính thuế/bảo hiểm.'),
        ('Chốt lương', 'Kỳ tháng 10/2026 được để mở để bạn tự thử Chốt lương, sau đó kiểm tra Lương đã chốt.'),
        ('Email', 'Chưa gửi email. Bạn tự thử Gửi cho từng nhân viên hoặc gửi một nhân viên trước.'),
        ('Xuất file', 'File mẫu này lấy từ API báo cáo dự kiến. Để xuất bản đã chốt trong app: chọn đúng kỳ → Xuất Excel, hoặc Lương đã chốt → tải kỳ cần xuất. Bản chốt giữ nguyên đơn giá và tiền tại thời điểm chốt.'),
        ('Dữ liệu hiện tại', 'Không thay đổi tài khoản, thẻ, khuôn mặt, ticket hoặc công tháng 11.'),
        ('Nhập lại mẫu', 'server/seed-october-2026.sql không tạo trùng khi chạy lại, và từ chối nếu tháng 10 có dữ liệu khác hoặc kỳ đã chốt.'),
    ]
    guide.append(['Mục', 'Hướng dẫn / tình huống mẫu'])
    for note in notes:
        guide.append(note)

    for ws, header_row, widths in [(summary, 4, [14, 34, 14, 14, 14, 17, 14, 23, 24]), (detail, 1, [14, 34, 15, 18, 15, 15, 54, 40]), (guide, 1, [24, 115])]:
        ws.freeze_panes = f'C{header_row + 1}'
        ws.sheet_view.showGridLines = False
        ws.print_options.horizontalCentered = True
        ws.sheet_properties.pageSetUpPr.fitToPage = True
        ws.page_setup.orientation = 'landscape'
        ws.page_setup.paperSize = ws.PAPERSIZE_A4
        ws.page_setup.fitToWidth = 1
        ws.page_setup.fitToHeight = 0
        ws.print_title_rows = f'1:{header_row}'
        for i, width in enumerate(widths, 1):
            ws.column_dimensions[get_column_letter(i)].width = width
        for cells in ws.iter_rows():
            for cell in cells:
                cell.font = Font(name='Calibri', size=11)
                cell.alignment = Alignment(vertical='center', wrap_text=True)
        for cell in ws[header_row]:
            cell.fill = PatternFill('solid', fgColor='263C59')
            cell.font = Font(name='Calibri', size=11, bold=True, color='FFFFFF')
        ws.row_dimensions[header_row].height = 32
    summary['A1'].font = Font(name='Calibri', size=18, bold=True, color='263C59')
    summary.row_dimensions[1].height = 32
    summary.row_dimensions[2].height = 30
    for row_number in range(5, 10):
        summary.cell(row_number, 4).number_format = '#,##0.00'
        for col in (8, 9):
            summary.cell(row_number, col).number_format = '#,##0 "đ"'
    for cell in summary[9]:
        cell.font = Font(name='Calibri', bold=True)
        cell.fill = PatternFill('solid', fgColor='E7EEF5')
    for row_number in range(2, detail.max_row + 1):
        detail.cell(row_number, 3).number_format = 'dd/mm/yyyy'
        detail.cell(row_number, 4).number_format = 'hh:mm:ss'
    for row_number in range(2, guide.max_row + 1):
        guide.row_dimensions[row_number].height = 42
    for ws, name, ref in [(summary, 'BaoCaoLuongMau', 'A4:I8'), (detail, 'ChamCongMau', f'A1:H{detail.max_row}')]:
        tab = Table(displayName=name, ref=ref)
        tab.tableStyleInfo = TableStyleInfo(name='TableStyleMedium2', showRowStripes=True)
        ws.add_table(tab)

    output = ROOT / 'docs/demo/bao_cao_luong_thang_10_2026.xlsx'
    output.parent.mkdir(parents=True, exist_ok=True)
    wb.save(output)
    check = load_workbook(output, read_only=True, data_only=True)
    assert check['Bao cao luong']['I9'].value == sum(r['gross_pay'] for r in rows)
    assert check['Chi tiet cham cong'].max_row == 341
    check.close()
    (ROOT / '.local-data/october-2026-report.json').write_text(json.dumps(rows, ensure_ascii=False, indent=2), encoding='utf-8')
    print('Verified API reporting totals and exported: ' + str(output))
    print(json.dumps([{'code': r['code'], 'days': r['days_worked'], 'hours': float(Decimal(str(r['worked_minutes'])) / 60), 'gross_pay': r['gross_pay']} for r in rows], indent=2))
    print('Total gross pay: ' + str(sum(r['gross_pay'] for r in rows)))


if __name__ == '__main__':
    main()
