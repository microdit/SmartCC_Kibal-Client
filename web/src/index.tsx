import React from 'react';
import ReactDOM from 'react-dom/client';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import App from './App';
import MediaDeviceTest from './components/MediaDeviceTest';

const root = document.getElementById('root');
if (!root) {
  throw new Error('#root element not found');
}

ReactDOM.createRoot(root).render(
  <React.StrictMode>
    <Router>
      <Routes>
        <Route path="/" element={<App />} />
        <Route path="/setting" element={<MediaDeviceTest />} />
      </Routes>
    </Router>
  </React.StrictMode>
);
