"""Generate sample workbooks and real XLS/XLSX regression fixtures (development only).

python -m pip install --target .local-data/excel-test-tools openpyxl xlwt
python scripts/generate_employee_import_fixtures.py
"""
from datetime import datetime
from pathlib import Path
import sys

root = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(root / '.local-data' / 'excel-test-tools'))
import openpyxl
import xlwt

fixtures = root / 'server' / 'Attendance.Tests' / 'Fixtures'
templates = root / 'docs' / 'templates'
fixtures.mkdir(parents=True, exist_ok=True)
templates.mkdir(parents=True, exist_ok=True)
headers = ['STT', 'Mã NV', 'Họ và\ntên', 'Chức\nvụ', 'Số điện\nthoại', 'Email', 'Ngày vào\nlàm', 'Phòng ban', 'Đơn giá giờ']
rows = [
    [1, 'KD01', 'Nguyễn Văn A', 'Trưởng phòng', '0901234567', 'a.nguyen@company.example', datetime(2023, 1, 15), 'Kinh doanh', 60000],
    [2, 'KD02', 'Trần Thị B', 'Phó phòng', 902345678, 'b.tran@company.example', datetime(2023, 3, 1), '', 50000],
    [3, 'KD03', 'Lê Văn C', 'Chuyên viên Kinh doanh', '0903456789', 'c.le@company.example', datetime(2024, 6, 10), 'Kinh doanh', 45000],
    [4, 'KD04', 'Phạm Thị D', 'Nhân viên Sale Online', '0904567890', 'd.pham@company.example', '12/01/2026', 'Kinh doanh', 45000],
]
book = openpyxl.Workbook()
sheet = book.active
sheet.title = 'Kinh doanh'
sheet.append(['DANH SÁCH NHÂN VIÊN (DỮ LIỆU VÍ DỤ)'])
sheet.append([])
sheet.append(headers)
for row in rows:
    sheet.append(row)
    sheet.cell(sheet.max_row, 7).number_format = 'dd/mm/yyyy'
    sheet.cell(sheet.max_row, 5).number_format = '0000000000' if isinstance(row[4], int) else '@'
sheet.freeze_panes = 'A4'
for col, width in zip('ABCDEFGHI', [8, 14, 24, 30, 20, 32, 20, 24, 18]):
    sheet.column_dimensions[col].width = width
book.save(fixtures / 'employees-valid.xlsx')
book.save(templates / 'nhan_vien_vi_du.xlsx')

legacy = xlwt.Workbook()
legacy_sheet = legacy.add_sheet('Kinh doanh')
legacy_sheet.write(0, 0, 'DANH SÁCH NHÂN VIÊN (DỮ LIỆU VÍ DỤ)')
for col, header in enumerate(headers):
    legacy_sheet.write(2, col, header)
for index, row in enumerate(rows, 3):
    for col, value in enumerate(row):
        style = xlwt.easyxf(num_format_str='DD/MM/YYYY') if isinstance(value, datetime) else xlwt.easyxf(num_format_str='0000000000') if col == 4 and isinstance(value, int) else xlwt.Style.default_style
        legacy_sheet.write(index, col, value, style)
legacy.save(str(fixtures / 'employees-valid.xls'))

conflict = openpyxl.Workbook()
conflict.active.append(headers)
conflict.active.append([1, 'KD05', 'Nhân viên mới', 'Nhân viên', '0905678901', 'new.person@company.example', '01/01/2026', 'Kinh doanh', 50000])
conflict.active.append([2, 'KD01', 'Mã nhân viên đã có', 'Nhân viên', '0906789012', 'different.person@company.example', '01/01/2026', 'Kinh doanh', 50000])
conflict.save(fixtures / 'employees-conflict.xlsx')

company = openpyxl.Workbook()
company.active.title = 'Cong nghe'
company.active.append(headers)
company.active.append([1, 'IT01', 'Nhân viên IT', 'Lập trình viên', '0901234567', 'it01@company.example', '01/01/2026', 'Công nghệ', 60000])
sales = company.create_sheet('Kinh doanh')
sales.append(headers)
sales.append([1, 'SALE01', 'Nhân viên kinh doanh', 'Nhân viên', '0902345678', 'sale01@company.example', '01/01/2026', 'Kinh doanh', 50000])
company.create_sheet('Huong dan').append(['Sheet ghi chú, không phải danh sách nhân viên'])
company.save(fixtures / 'employees-multisheet.xlsx')

template = openpyxl.Workbook()
template.active.title = 'Nhan vien'
template.active.append([header.replace('\n', ' ') for header in headers])
template.active.column_dimensions['E'].number_format = '@'
template.active.freeze_panes = 'A2'
template.save(templates / 'nhan_vien_mau.xlsx')
print('Generated four regression fixtures and two sample Excel files.')

# NFC import fixtures: UID cells must be literal text, never numeric conversions.
def nfc_file(name, data):
    wb = openpyxl.Workbook()
    wb.active.append(['Mã NV', 'Họ và tên', 'Email', 'uid_the'])
    for row in data:
        wb.active.append(row)
        wb.active.cell(wb.active.max_row, 4).number_format = '@'
    wb.save(fixtures / name)

nfc_file('employees-nfc.xlsx', [
    ['NFC01', 'Nhan vien NFC 1', 'nfc01@company.example', '04:00:AA:01'],
    ['NFC02', 'Nhan vien NFC 2', 'nfc02@company.example', '04-00-AA-02'],
    ['NFC03', 'Nhan vien NFC 3', 'nfc03@company.example', ''],
])
nfc_file('employees-nfc-link.xlsx', [['NFC03', 'Nhan vien NFC 3', 'nfc03@company.example', '0400AA03']])
nfc_file('employees-nfc-conflict.xlsx', [
    ['NFC04', 'Must not be created', 'nfc04@company.example', '0400AA04'],
    ['NFC05', 'Conflicting UID', 'nfc05@company.example', '0400AA01'],
])
nfc_file('employees-nfc-replace.xlsx', [['NFC01', 'Nhan vien NFC 1', 'nfc01@company.example', '0400AA09']])
nfc_file('employees-nfc-duplicate.xlsx', [
    ['NFC06', 'Duplicate 1', 'nfc06@company.example', '04:00:AA:06'],
    ['NFC07', 'Duplicate 2', 'nfc07@company.example', '0400aa06'],
])
# Keep the published blank template aligned with the API template.
wb = openpyxl.Workbook()
wb.active.append(['STT', 'Mã NV', 'Họ và tên', 'Phòng ban', 'Chức vụ', 'Số điện thoại', 'Email', 'Ngày vào làm', 'Đơn giá giờ', 'uid_the'])
wb.active.column_dimensions['J'].number_format = '@'
wb.save(templates / 'nhan_vien_mau.xlsx')

wb = openpyxl.Workbook()
wb.active.append(['Code', 'Full Name', 'Email', 'uid_the'])
wb.active.append(['NUM01', 'Numeric UID', 'num01@company.example', 400000000000000001])
wb.active.cell(2, 4).number_format = '000000000000000000'
wb.save(fixtures / 'employees-nfc-numeric.xlsx')
legacy = xlwt.Workbook()
ws = legacy.add_sheet('NFC')
for c, v in enumerate(['Code', 'Full Name', 'Email', 'UID NFC']): ws.write(0, c, v)
for c, v in enumerate(['NFC01', 'Legacy NFC', 'legacy@company.example', '00:04:AA:01']): ws.write(1, c, v)
legacy.save(str(fixtures / 'employees-nfc.xls'))

# Regression workbook uses the supplied layout, with synthetic employee identities.
wb = openpyxl.load_workbook(fixtures / 'employees-valid.xlsx')
ws = wb.active
ws.cell(3, 10, 'uid_the')
for i in range(4, 8):
    ws.cell(i, 2, f'FMT{i-3:02}')
    ws.cell(i, 3, f'Nhan vien mau {i-3}')
    ws.cell(i, 6, f'format{i-3}@company.example')
    ws.cell(i, 8, 'IT')
    ws.cell(i, 10, f'0004CC{i-3:02}')
    ws.cell(i, 10).number_format = '@'
wb.save(fixtures / 'employees-company-layout.xlsx')
wb = openpyxl.Workbook()
ws = wb.active
ws.title = 'Kinh doanh'
ws.append(['DANH SÁCH NHÂN VIÊN'])
ws.append([])
ws.append(headers + ['uid_the'])
ws.append([1, 'KD01', 'Ten da cap nhat', 'Lap trinh vien', '0909999888',
           'a.nguyen@company.example', datetime(2024, 2, 20), 'IT', 70000, '0004BB01'])
ws.cell(4, 7).number_format = 'dd/mm/yyyy'
ws.cell(4, 10).number_format = '@'
wb.save(fixtures / 'employees-profile-update.xlsx')
# Downloaded template follows the user's column order and row-three header.
wb = openpyxl.Workbook()
ws = wb.active
ws.title = 'Kinh doanh'
ws.append(['DANH SÁCH NHÂN VIÊN'])
ws.append([])
ws.append(headers + ['uid_the'])
ws.column_dimensions['E'].number_format = '@'
ws.column_dimensions['J'].number_format = '@'
ws.freeze_panes = 'A4'
wb.save(templates / 'nhan_vien_mau.xlsx')
