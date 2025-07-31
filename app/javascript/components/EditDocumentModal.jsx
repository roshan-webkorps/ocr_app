import React, { useState } from 'react';

const EditDocumentModal = ({ document, onSave, onClose }) => {
  const [name, setName] = useState(document?.name || '');
  const [isLoading, setIsLoading] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!name.trim()) return;

    setIsLoading(true);
    try {
      await onSave(document.id, { name: name.trim() });
      onClose();
    } catch (error) {
      alert('Failed to update document name');
    } finally {
      setIsLoading(false);
    }
  };

  if (!document) return null;

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-content" onClick={(e) => e.stopPropagation()}>
        <h3>Edit Document Name</h3>
        <form onSubmit={handleSubmit}>
          <div style={{ marginBottom: '1rem' }}>
            <label style={{ display: 'block', marginBottom: '0.5rem' }}>
              Document Name:
            </label>
            <input
              type="text"
              value={name}
              onChange={(e) => setName(e.target.value)}
              style={{
                width: '100%',
                padding: '0.5rem',
                border: '1px solid #ddd',
                borderRadius: '4px'
              }}
              disabled={isLoading}
            />
          </div>
          <div className="flex gap-2">
            <button
              type="submit"
              className="btn"
              disabled={isLoading || !name.trim()}
            >
              {isLoading ? 'Saving...' : 'Save'}
            </button>
            <button
              type="button"
              onClick={onClose}
              className="btn btn-secondary"
              disabled={isLoading}
            >
              Cancel
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};

export default EditDocumentModal;
