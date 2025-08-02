class DocumentsController < ApplicationController
  before_action :set_document, only: [ :show, :update, :destroy, :download_original, :download_excel ]

  def index
    @documents = Document.order(created_at: :desc)
    respond_to do |format|
      format.html
      format.json { render json: @documents.as_json(methods: [ :completed?, :failed?, :processing? ]) }
    end
  end

  def show
    respond_to do |format|
      format.html
      format.json do
        render json: {
          document: @document.as_json(methods: [ :completed?, :failed?, :processing? ]),
          extracted_data: @document.extracted_data.select(:key, :value, :data_type)
        }
      end
    end
  end

  def create
    uploaded_files = params[:files] || []
    created_documents = []
    errors = []

    uploaded_files.each do |file|
      unless valid_file_type?(file.content_type)
        errors << "#{file.original_filename}: Invalid file type. Only JPG, PNG, and PDF files are allowed."
        next
      end

      if file.size > 10.megabytes
        errors << "#{file.original_filename}: File too large. Maximum size is 10MB."
        next
      end

      document = Document.new(
        name: File.basename(file.original_filename, File.extname(file.original_filename)),
        original_filename: file.original_filename,
        content_type: file.content_type,
        file_size: file.size
      )

      if document.save
        document.file.attach(file)
        created_documents << document

        DocumentProcessorJob.perform_later(document.id)
      else
        errors << "#{file.original_filename}: #{document.errors.full_messages.join(', ')}"
      end
    end

    respond_to do |format|
      if created_documents.any?
        format.json {
          render json: {
            message: "#{created_documents.count} file(s) uploaded successfully. Processing will begin shortly.",
            documents: created_documents.as_json(methods: [ :completed?, :failed?, :processing? ]),
            errors: errors
          }, status: :created
        }
        format.html {
          redirect_to documents_path,
          notice: "#{created_documents.count} file(s) uploaded successfully. Processing will begin shortly."
        }
      else
        format.json {
          render json: {
            error: "Failed to upload files",
            errors: errors
          }, status: :unprocessable_entity
        }
        format.html {
          redirect_to documents_path,
          alert: "Failed to upload files: #{errors.join(', ')}"
        }
      end
    end
  end

  def update
    if @document.update(document_params)
      respond_to do |format|
        format.html { redirect_to @document, notice: "Document updated successfully." }
        format.json { render json: @document.as_json(methods: [ :completed?, :failed?, :processing? ]) }
      end
    else
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: { errors: @document.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @document.destroy
    respond_to do |format|
      format.html { redirect_to documents_url, notice: "Document deleted successfully." }
      format.json { head :no_content }
    end
  end

  def download_original
    if @document.file.attached?
      respond_to do |format|
        format.html do
          redirect_to rails_blob_path(@document.file, disposition: "attachment")
        end
        format.json do
          render json: {
            download_url: rails_blob_url(@document.file, disposition: "attachment"),
            filename: @document.original_filename,
            file_size: @document.file_size
          }
        end
      end
    else
      respond_to do |format|
        format.html { redirect_to documents_path, alert: "Original file not found." }
        format.json { render json: { error: "Original file not found" }, status: :not_found }
      end
    end
  end

  def download_excel
    return redirect_to @document, alert: "No data available for export." unless @document.status == "completed" && @document.extracted_data.any?

    excel_package = ExcelExportService.generate_excel(@document)
    return redirect_to @document, alert: "Unable to generate Excel file." unless excel_package

    filename = "#{@document.name.parameterize}_data.xlsx"

    send_data excel_package.to_stream.read,
              filename: filename,
              type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
              disposition: "attachment"
  end

  private

  def set_document
    @document = Document.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    respond_to do |format|
      format.html { redirect_to documents_path, alert: "Document not found." }
      format.json { render json: { error: "Document not found" }, status: :not_found }
    end
  end

  def document_params
    params.require(:document).permit(:name)
  end

  def valid_file_type?(content_type)
    %w[
      image/jpeg
      image/jpg
      image/png
      application/pdf
    ].include?(content_type)
  end
end
