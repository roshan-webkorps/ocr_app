import React, { useState, useRef } from 'react';

const UploadModal = ({ isOpen, onClose, onUpload, isUploading }) => {
  const [isDragging, setIsDragging] = useState(false);
  const fileInputRef = useRef(null);

  const handleDragOver = (e) => {
    e.preventDefault();
    setIsDragging(true);
  };

  const handleDragLeave = (e) => {
    e.preventDefault();
    setIsDragging(false);
  };

  const handleDrop = (e) => {
    e.preventDefault();
    setIsDragging(false);
    
    const files = Array.from(e.dataTransfer.files);
    if (files.length > 0) {
        onUpload(files);
    }
    };

  const handleFileSelect = (e) => {
    const files = Array.from(e.target.files);
    if (files.length > 0) {
        onUpload(files);
        e.target.value = '';
    }
    };

  const handleUploadAreaClick = () => {
    fileInputRef.current?.click();
  };

  const handleOverlayClick = (e) => {
    if (e.target === e.currentTarget && !isUploading) {
      onClose();
    }
  };

  if (!isOpen) return null;

  return (
    <div className="modal-overlay" onClick={handleOverlayClick}>
      <div className="upload-modal-content" onClick={(e) => e.stopPropagation()}>
        <div className="upload-modal-header">
          <h3>Upload Documents</h3>
          {!isUploading && (
            <button className="modal-close-btn" onClick={onClose}>
              ×
            </button>
          )}
        </div>
        
        <div className="upload-modal-body">
          <div
            className={`upload-area ${isDragging ? 'dragging' : ''}`}
            onDragOver={handleDragOver}
            onDragLeave={handleDragLeave}
            onDrop={handleDrop}
            onClick={handleUploadAreaClick}
          >
            <input
              ref={fileInputRef}
              type="file"
              multiple
              accept="image/*,.pdf"
              onChange={handleFileSelect}
              style={{ display: 'none' }}
              disabled={isUploading}
            />
            
            {isUploading ? (
              <div className="upload-progress">
                <div className="upload-spinner"></div>
                <h4>Uploading files...</h4>
                <p>Please wait while your files are being uploaded and queued for processing.</p>
              </div>
            ) : (
              <div className="upload-content">
                <div className="upload-icon">📁</div>
                <h4>Drop files here or click to browse</h4>
                <p>Supports JPG, PNG, and PDF files up to 10MB each</p>
                <button type="button" className="btn btn-upload">
                  Choose Files
                </button>
              </div>
            )}
          </div>
        </div>
        
        {!isUploading && (
          <div className="upload-modal-footer">
            <button className="btn btn-secondary" onClick={onClose}>
              Cancel
            </button>
          </div>
        )}
      </div>
    </div>
  );
};

export default UploadModal;
