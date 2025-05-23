import React, { createContext, useState, useContext, useEffect, ReactNode } from 'react';
import axios from 'axios';

// Benutzertyp
interface User {
    username: string;
    token: string;
    isAdmin: boolean;
}

// Auth-Kontext Schnittstelle
interface AuthContextType {
    isAuthenticated: boolean;
    isAdmin: boolean;
    user: User | null;
    login: (userData: User) => Promise<void>;
    logout: () => void;
}

// Erstelle den Auth-Kontext
const AuthContext = createContext<AuthContextType>({
    isAuthenticated: false,
    isAdmin: false,
    user: null,
    login: async () => {},
    logout: () => {},
});

// Custom Hook für einfachen Zugriff auf den Auth-Kontext
export const useAuth = () => useContext(AuthContext);

// Provider-Komponente
export const AuthProvider: React.FC<{ children: ReactNode }> = ({ children }) => {
    const [user, setUser] = useState<User | null>(null);
    const [isAuthenticated, setIsAuthenticated] = useState(false);
    const [isAdmin, setIsAdmin] = useState(false);

    // Beim Start der Anwendung den gespeicherten Benutzer laden
    useEffect(() => {
        const storedUser = localStorage.getItem('exapg_user');
        if (storedUser) {
            try {
                const parsedUser = JSON.parse(storedUser) as User;
                setUser(parsedUser);
                setIsAuthenticated(true);
                setIsAdmin(parsedUser.isAdmin);
                
                // Axios-Header für Authentifizierung setzen
                axios.defaults.headers.common['Authorization'] = `Bearer ${parsedUser.token}`;
            } catch (error) {
                console.error('Fehler beim Laden des gespeicherten Benutzers:', error);
                localStorage.removeItem('exapg_user');
            }
        }
    }, []);

    // Login-Funktion
    const login = async (userData: User): Promise<void> => {
        // Benutzer speichern
        setUser(userData);
        setIsAuthenticated(true);
        setIsAdmin(userData.isAdmin);
        
        // Speichere Benutzer im localStorage
        localStorage.setItem('exapg_user', JSON.stringify(userData));
        
        // Axios-Header für Authentifizierung setzen
        axios.defaults.headers.common['Authorization'] = `Bearer ${userData.token}`;
    };

    // Logout-Funktion
    const logout = () => {
        setUser(null);
        setIsAuthenticated(false);
        setIsAdmin(false);
        localStorage.removeItem('exapg_user');
        
        // Entferne Auth-Header
        delete axios.defaults.headers.common['Authorization'];
    };

    return (
        <AuthContext.Provider
            value={{
                isAuthenticated,
                isAdmin,
                user,
                login,
                logout,
            }}
        >
            {children}
        </AuthContext.Provider>
    );
};

export default AuthContext; 