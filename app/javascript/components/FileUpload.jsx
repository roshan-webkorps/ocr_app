import React, { useState, useRef } from 'react';

const FileUpload = ({ onUpload, isUploading }) => {
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
    }
  };

  const handleClick = () => {
    fileInputRef.current?.click();
  };

  return (
    <div className="card">
      <div
        className={`upload-area ${isDragging ? 'dragging' : ''}`}
        onDragOver={handleDragOver}
        onDragLeave={handleDragLeave}
        onDrop={handleDrop}
        onClick={handleClick}
      >
        <input
          ref={fileInputRef}
          type="file"
          multiple
          accept="image/*,.pdf"
          onChange={handleFileSelect}
          style={{ display: 'none' }}
        />
        
        {isUploading ? (
          <div>
            <div className="upload-spinner"></div>
            <h3>Uploading files...</h3>
            <p>Please wait while your files are being uploaded.</p>
          </div>
        ) : (
          <div>
            <div className="upload-icon">📁</div>
            <h3>Drop files here or click to browse</h3>
            <p>Supports JPG, PNG, and PDF files up to 10MB each</p>
            <button type="button" className="btn">
              Choose Files
            </button>
          </div>
        )}
      </div>
    </div>
  );
};

export default FileUpload;
