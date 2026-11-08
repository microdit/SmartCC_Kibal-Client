/** @format */

import { NavLink, useLocation } from 'react-router-dom';
import { Phone, Video, History, Settings, Menu } from 'lucide-react';
import { useState } from 'react';

const navItems = [
  { to: '/dialer', label: 'Dialer', icon: Phone },
  { to: '/calls', label: 'Calls', icon: Video },
  { to: '/history', label: 'History', icon: History },
  { to: '/settings', label: 'Settings', icon: Settings },
];

export default function Header() {
  const location = useLocation();
  const [menuOpen, setMenuOpen] = useState(false);

  return (
    <header className="bg-gray-800 border-b border-gray-700 px-4 py-3 flex items-center justify-between">
      <div className="flex items-center space-x-4">
        <button
          className="md:hidden p-2 rounded hover:bg-gray-700"
          onClick={() => setMenuOpen(!menuOpen)}
        >
          <Menu className="w-5 h-5" />
        </button>
        <h1 className="text-xl font-bold text-white">Kibal SIP Client</h1>
      </div>

      <nav className={`md:flex ${menuOpen ? 'flex' : 'hidden'} flex-col md:flex-row md:items-center space-y-2 md:space-y-0 md:space-x-2`}>
        {navItems.map(({ to, label, icon: Icon }) => (
          <NavLink
            key={to}
            to={to}
            className={({ isActive }) =>
              `flex items-center space-x-2 px-3 py-2 rounded transition-colors ${
                isActive || location.pathname === to
                  ? 'bg-blue-600 text-white'
                  : 'text-gray-300 hover:bg-gray-700 hover:text-white'
              }`
            }
          >
            <Icon className="w-4 h-4" />
            <span>{label}</span>
          </NavLink>
        ))}
      </nav>
    </header>
  );
}
