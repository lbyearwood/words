import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { HashRouter } from 'react-router-dom'
import { App } from './App'
import { AuthProvider } from './state/AuthContext'
import { SoundProvider } from './state/SoundContext'
import './styles.css'

const queryClient = new QueryClient({
  defaultOptions: {
    queries: { staleTime: 20_000, retry: 1, refetchOnWindowFocus: false },
  },
})

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
