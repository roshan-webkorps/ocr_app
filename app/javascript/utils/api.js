const API_BASE = '';

// Get CSRF token for Rails
const getCSRFToken = () => {
  const token = document.querySelector('[name="csrf-token"]');
  return token ? token.getAttribute('content') : '';
};

// Default headers for API requests
const getHeaders = () => ({
  'Content-Type': 'application/json',
  'X-CSRF-Token': getCSRFToken(),
});

// API functions
export const documentsAPI = {
  // Get all documents
  getAll: async () => {
    const response = await fetch(`${API_BASE}/documents.json`);
    if (!response.ok) throw new Error('Failed to fetch documents');
    return response.json();
  },

  // Get single document with extracted data
  get: async (id) => {
    const response = await fetch(`${API_BASE}/documents/${id}.json`);
    if (!response.ok) throw new Error('Failed to fetch document');
    return response.json();
  },

  // Upload files
  upload: async (files) => {
    const formData = new FormData();
    Array.from(files).forEach(file => {
      formData.append('files[]', file);
    });

    const response = await fetch(`${API_BASE}/documents`, {
      method: 'POST',
      headers: {
        'X-CSRF-Token': getCSRFToken(),
      },
      body: formData,
    });

    if (!response.ok) throw new Error('Failed to upload files');
    return response.json();
  },

  // Update document (rename)
  update: async (id, data) => {
    const response = await fetch(`/documents/${id}`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',        // Add this line!
        'X-CSRF-Token': getCSRFToken(),
      },
      body: JSON.stringify({ document: data }),
    });

    if (!response.ok) throw new Error('Failed to update document');
    return response.json();
  },

  // Delete document
  delete: async (id) => {
    const response = await fetch(`/documents/${id}`, {
      method: 'DELETE',
      headers: {
        'X-CSRF-Token': getCSRFToken(),
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
      credentials: 'same-origin',
    });

    if (!response.ok) throw new Error('Failed to delete document');
    return true;
  },
};
