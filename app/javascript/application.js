import React from 'react'
import { createRoot } from 'react-dom/client'
import IndexPage from './pages/IndexPage'
import ShowPage from './pages/ShowPage'

document.addEventListener('DOMContentLoaded', () => {
  const appElement = document.getElementById('react-app')
  
  if (appElement) {
    const page = appElement.dataset.page
    const root = createRoot(appElement)
    
    switch (page) {
      case 'index':
        root.render(<IndexPage />)
        break
      case 'show':
        const documentId = appElement.dataset.documentId
        root.render(<ShowPage documentId={documentId} />)
        break
      default:
        console.error('Unknown page:', page)
    }
  }
})
