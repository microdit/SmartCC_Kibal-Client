/** @format */

import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { useSipStore } from '@/store/sipStore';
import AppLayout from '@/components/layout/AppLayout';
import LoginPage from '@/pages/LoginPage';
import DialerPage from '@/pages/DialerPage';
import CallPage from '@/pages/CallPage';
import ConferencePage from '@/pages/ConferencePage';
import HistoryPage from '@/pages/HistoryPage';
import SettingsPage from '@/pages/SettingsPage';

function AppRoutes() {
  const { registration } = useSipStore();
  const isRegistered = registration.state === 'registered';

  return (
    <BrowserRouter>
      <Routes>
        <Route path="/login" element={!isRegistered ? <LoginPage /> : <Navigate to="/dialer" replace />} />

        <Route element={<AppLayout />}>
          <Route index element={<Navigate to="/dialer" replace />} />
          <Route path="dialer" element={<DialerPage />} />
          <Route path="calls" element={<CallPage />} />
          <Route path="conference" element={<ConferencePage />} />
          <Route path="history" element={<HistoryPage />} />
          <Route path="settings" element={<SettingsPage />} />
        </Route>

        <Route path="*" element={<Navigate to="/dialer" replace />} />
      </Routes>
    </BrowserRouter>
  );
}

export default AppRoutes;
