# app/services/excel_export_service.rb
class ExcelExportService
  def self.generate_excel(document)
    return nil unless document&.extracted_data&.any?

    package = Axlsx::Package.new
    workbook = package.workbook

    header_style = workbook.styles.add_style(
      b: true,
      bg_color: "366092",
      fg_color: "FFFFFF",
      border: { style: :thin, color: "000000" },
      alignment: { horizontal: :center }
    )

    data_style = workbook.styles.add_style(
      border: { style: :thin, color: "CCCCCC" },
      alignment: { vertical: :top }
    )

    workbook.add_worksheet(name: "Extracted Data") do |sheet|
      sheet.add_row [ "Field", "Value" ], style: header_style

      document.extracted_data.each do |data|
        formatted_key = data.key.to_s.humanize
        sheet.add_row [ formatted_key, data.value ], style: data_style
      end

      sheet.column_widths 30, 50

      sheet.auto_filter = "A1:B1"
    end

    package
  end
end
