import React, { useState, useEffect } from 'react';
import DocumentsTable from '../components/DocumentsTable';
import EditDocumentModal from '../components/EditDocumentModal';
import UploadModal from '../components/UploadModal';
import { documentsAPI } from '../utils/api';

const IndexPage = () => {
  const [documents, setDocuments] = useState([]);
  const [isUploading, setIsUploading] = useState(false);
  const [isLoading, setIsLoading] = useState(true);
  const [editingDocument, setEditingDocument] = useState(null);
  const [showUploadModal, setShowUploadModal] = useState(false);
  const [message, setMessage] = useState(null);

  // Load documents on component mount
  useEffect(() => {
    loadDocuments();
  }, []);

  const loadDocuments = async () => {
    try {
      const data = await documentsAPI.getAll();
      setDocuments(data);
    } catch (error) {
      console.error('Failed to load documents:', error);
      setMessage({ type: 'error', text: 'Failed to load documents' });
    } finally {
      setIsLoading(false);
    }
  };

  const handleFileUpload = async (files) => {
    setIsUploading(true);
    try {
      const result = await documentsAPI.upload(files);
      setMessage({ 
        type: 'success', 
        text: result.message 
      });
      
      // Close modal and refresh the documents list
      setShowUploadModal(false);
      await loadDocuments();
    } catch (error) {
      console.error('Upload failed:', error);
      setMessage({ 
        type: 'error', 
        text: 'Failed to upload files. Please try again.' 
      });
    } finally {
      setIsUploading(false);
    }
  };

  const handleView = (documentId) => {
    window.location.href = `/documents/${documentId}`;
  };

  const handleEdit = (document) => {
    setEditingDocument(document);
  };

  const handleSaveEdit = async (documentId, data) => {
    await documentsAPI.update(documentId, data);
    await loadDocuments(); // Refresh the list
    setMessage({ type: 'success', text: 'Document updated successfully' });
  };

  const handleDelete = async (documentId) => {
    if (!confirm('Are you sure you want to delete this document?')) {
      return;
    }

    try {
      await documentsAPI.delete(documentId);
      await loadDocuments();
      setMessage({ type: 'success', text: 'Document deleted successfully' });
    } catch (error) {
      console.error('Delete failed:', error);
      setMessage({ type: 'error', text: 'Failed to delete document' });
    }
  };

  const closeMessage = () => {
    setMessage(null);
  };

  if (isLoading) {
    return (
      <div className="loading-container">
        <div className="loading-spinner"></div>
        <h3>Loading documents...</h3>
        <p>Please wait while we fetch your documents.</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      {/* Header with Upload Button */}
      <div className="page-header">
        <div>
          <h1>OCR Document Processor</h1>
          <p className="page-subtitle">
            Upload documents and extract data automatically using AI-powered OCR
          </p>
        </div>
        <button 
          className="btn btn-primary btn-large"
          onClick={() => setShowUploadModal(true)}
        >
          Upload Documents
        </button>
      </div>

      {/* Alert Messages */}
      {message && (
        <div className={`alert alert-${message.type}`}>
          <span>{message.text}</span>
          <button onClick={closeMessage} className="alert-close">×</button>
        </div>
      )}

      {/* Documents Table or Empty State */}
      {documents.length > 0 ? (
        <DocumentsTable
          documents={documents}
          onView={handleView}
          onEdit={handleEdit}
          onDelete={handleDelete}
          onRefresh={loadDocuments}
        />
      ) : (
        <div className="empty-state-card">
          <div className="empty-state">
            <div className="empty-state-icon">📄</div>
            <h3>No documents uploaded yet</h3>
            <p>Get started by uploading your first document for OCR processing.</p>
            <button 
              className="btn btn-primary"
              onClick={() => setShowUploadModal(true)}
            >
              Upload Your First Document
            </button>
          </div>
        </div>
      )}

      {/* Upload Modal */}
      <UploadModal
        isOpen={showUploadModal}
        onClose={() => !isUploading && setShowUploadModal(false)}
        onUpload={handleFileUpload}
        isUploading={isUploading}
      />

      {/* Edit Document Modal */}
      {editingDocument && (
        <EditDocumentModal
          document={editingDocument}
          onSave={handleSaveEdit}
          onClose={() => setEditingDocument(null)}
        />
      )}
    </div>
  );
};

export default IndexPage;
