import React, { useState, useEffect } from 'react';
import { documentsAPI } from '../utils/api';

const ShowPage = ({ documentId }) => {
  const [data, setData] = useState(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    loadDocument();
  }, [documentId]);

  const loadDocument = async () => {
    try {
      const result = await documentsAPI.get(documentId);
      setData(result);
    } catch (err) {
      setError('Failed to load document details');
      console.error('Failed to load document:', err);
    } finally {
      setIsLoading(false);
    }
  };

  const handleBack = () => {
    window.location.href = '/';
  };

  if (isLoading) {
    return (
      <div className="loading-container">
        <div className="loading-spinner"></div>
        <h3>Loading document details...</h3>
        <p>Please wait while we fetch your document.</p>
      </div>
    );
  }

  if (error) {
    return (
      <div className="card">
        <div style={{ textAlign: 'center', padding: '2rem' }}>
          <h3>Error</h3>
          <p>{error}</p>
          <button onClick={handleBack} className="btn">
            ← Back to Documents
          </button>
        </div>
      </div>
    );
  }

  const { document, extracted_data } = data;

  return (
    <div className="document-details">
      {/* Improved Header */}
      <div className="details-header-improved">
        <div className="header-content">
          <button onClick={handleBack} className="btn btn-secondary">
            ← Back
          </button>
          <h1>{document.name}</h1>
          <div className="header-actions">
            {document.status === 'completed' && (
              <>
                <a
                  href={`/documents/${document.id}/download_original`}
                  className="btn btn-secondary"
                >
                  Download Original
                </a>
                <a
                  href={`/documents/${document.id}/download_excel`}
                  className="btn btn-excel"
                >
                  Download Excel File
                </a>
              </>
            )}
          </div>
        </div>
      </div>

      {/* Processing States */}
      {document.status === 'processing' && (
        <div className="status-card processing">
          <div className="loading-spinner"></div>
          <h3>Processing Document</h3>
          <p>AI is extracting data from your document. This usually takes 10-30 seconds.</p>
          <button onClick={loadDocument} className="btn btn-secondary">
            Check Status
          </button>
        </div>
      )}

      {document.status === 'failed' && (
        <div className="status-card failed">
          <h3>Processing Failed</h3>
          <p>There was an error processing this document.</p>
          {document.error_message && (
            <div className="error-details">
              <strong>Error details:</strong> {document.error_message}
            </div>
          )}
        </div>
      )}

      {/* Extracted Data - Improved Table */}
      {document.status === 'completed' && (
        <>
          {extracted_data && extracted_data.length > 0 ? (
            <div className="extracted-data-section-improved">
              <h2>Extracted Data</h2>
              <div className="table-container">
                <table className="extracted-data-table">
                  <tbody>
                    {extracted_data.map((item, index) => (
                      <tr key={index}>
                        <td className="field-name-bold">
                          {item.key.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase())}
                        </td>
                        <td className="field-value">{item.value}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          ) : (
            <div className="empty-data">
              <h3>No data extracted</h3>
              <p>The AI couldn't extract any relevant information from this document.</p>
            </div>
          )}
        </>
      )}
    </div>
  );
};

export default ShowPage;
