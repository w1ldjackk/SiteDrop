// resources/js/hooks/useAuth.ts
import { useState, useEffect } from 'react';
import axios from '../axios';
import { setAuthToken } from '../axios';

interface User {
    id: number;
    name: string;
    email: string;
    phone: string;
    role: string;
    phone_verified: boolean;
}

interface LoginData {
    login: string;
    password: string;
    remember?: boolean;
}

interface RegisterData {
    name: string;
    email: string;
    phone: string;
    phone_country: string;
    role: string;
    password: string;
}

interface AuthResponse {
    token: string;
    user: User;
}

export const useAuth = () => {
    const [user, setUser] = useState<User | null>(null);
    const [loading, setLoading] = useState<boolean>(true);

    const checkAuth = async () => {
        try {
            const res = await axios.get<User>('/api/user');
            setUser(res.data);
        } catch {
            setUser(null);
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        checkAuth();
    }, []);

    const login = async (data: LoginData) => {
        const res = await axios.post<AuthResponse>('/api/auth/login', data);
        setAuthToken(res.data.token);
        setUser(res.data.user);
        return res.data;
    };

    const logout = async () => {
        await axios.post('/api/auth/logout');
        setAuthToken('');
        setUser(null);
    };

    const register = async (data: RegisterData) => {
        const res = await axios.post<AuthResponse>('/api/auth/register', data);
        setAuthToken(res.data.token);
        setUser(res.data.user);
        return res.data;
    };

    // ====================== OTP LOGIN FLOW ======================
    const loginOtp = async (phone: string) => {
        const res = await axios.post('/api/auth/login-otp', { phone });
        return res.data;
    };

    const verifyOtp = async (phone: string, otp: string) => {
        const res = await axios.post<AuthResponse>('/api/auth/otp/verify', {
            phone,
            otp,
        });
        setAuthToken(res.data.token);
        setUser(res.data.user);
        return res.data;
    };

    const sendOtp = async (phone: string) => {
        const res = await axios.post('/api/auth/otp/send', { phone });
        return res.data;
    };

    return {
        user,
        loading,
        login,
        logout,
        register,
        loginOtp,
        verifyOtp,
        sendOtp,
    };
};
