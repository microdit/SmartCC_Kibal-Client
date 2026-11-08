/** @format */

import { Outlet } from 'react-router-dom';
import { StoreProvider } from '@/providers/StoreProvider';
import { SipProvider } from '@/providers/SipProvider';
import { MediaProvider } from '@/providers/MediaProvider';
import Header from '@/components/layout/Header';
import Footer from '@/components/layout/Footer';

export default function AppLayout() {
  return (
    <StoreProvider>
      <SipProvider>
        <MediaProvider>
          <div className="flex flex-col min-h-screen bg-gray-900 text-gray-100">
            <Header />
            <main className="flex-1 overflow-auto">
              <Outlet />
            </main>
            <Footer />
          </div>
        </MediaProvider>
      </SipProvider>
    </StoreProvider>
  );
}
