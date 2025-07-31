import React from 'react';

const DocumentsTable = ({ documents, onView, onEdit, onDelete, onRefresh }) => {
  const getStatusColor = (status) => {
    switch (status) {
      case 'completed': return 'status-completed';
      case 'processing': return 'status-processing';
      case 'failed': return 'status-failed';
      default: return 'status-pending';
    }
  };

  const formatDate = (dateString) => {
    return new Date(dateString).toLocaleDateString('en-US', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    });
  };

  const formatFileSize = (bytes) => {
    if (bytes === 0) return '0 Bytes';
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
  };

  if (documents.length === 0) {
    return (
      <div className="card">
        <div style={{ textAlign: 'center', padding: '2rem' }}>
          <h3>No documents uploaded yet</h3>
          <p>Upload your first document to get started with OCR extraction.</p>
        </div>
      </div>
    );
  }

  return (
    <div className="card">
      <h2 style={{ marginBottom: '1rem' }}>Documents</h2>
      
      <table className="table">
        <thead>
          <tr>
            <th>Name</th>
            <th>Status</th>
            <th>Size</th>
            <th>Uploaded</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          {documents.map((document) => (
            <tr key={document.id}>
              <td>
                <div>
                  <div style={{ fontWeight: '600' }}>{document.name}</div>
                  <div style={{ fontSize: '0.8rem', color: '#666' }}>
                    {document.original_filename}
                  </div>
                </div>
              </td>
              <td>
                <span className={getStatusColor(document.status)}>
                  {document.status.charAt(0).toUpperCase() + document.status.slice(1)}
                </span>
              </td>
              <td>{formatFileSize(document.file_size)}</td>
              <td>{formatDate(document.created_at)}</td>
              <td>
                <div className="flex gap-2">
                  <button
                    onClick={() => onView(document.id)}
                    className="btn"
                    style={{ fontSize: '0.8rem', padding: '0.25rem 0.5rem' }}
                  >
                    View
                  </button>
                  <button
                    onClick={() => onEdit(document)}
                    className="btn btn-secondary"
                    style={{ fontSize: '0.8rem', padding: '0.25rem 0.5rem' }}
                  >
                    Edit
                  </button>
                  <button
                    onClick={() => onDelete(document.id)}
                    className="btn btn-danger"
                    style={{ fontSize: '0.8rem', padding: '0.25rem 0.5rem' }}
                  >
                    Delete
                  </button>
                  {document.status === 'completed' && (
                    <a
                      href={`/documents/${document.id}/download_excel`}
                      className="btn btn-excel"
                      style={{ fontSize: '0.8rem', padding: '0.25rem 0.5rem' }}
                    >
                      Download Excel File
                    </a>
                  )}
                </div>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
};

export default DocumentsTable;
