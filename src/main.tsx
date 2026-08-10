import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { QueryClientProvider } from '@tanstack/react-query'
import { HashRouter } from 'react-router-dom'
import { App } from './App'
import { queryClient, startPersistentQueryCache } from './lib/queryCache'
import { AuthProvider } from './state/AuthContext'
import { SoundProvider } from './state/SoundContext'
import './styles.css'

startPersistentQueryCache()

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <QueryClientProvider client={queryClient}>
      <AuthProvider>
        <SoundProvider>
          <HashRouter>
            <App />
          </HashRouter>
        </SoundProvider>
      </AuthProvider>
    </QueryClientProvider>
  </StrictMode>,
)
