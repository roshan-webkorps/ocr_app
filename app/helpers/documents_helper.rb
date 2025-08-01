module DocumentsHelper
  def excel_download_filename(document)
    base_name = document.name.parameterize
    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    "#{base_name}_data_#{timestamp}.xlsx"
  end
end
