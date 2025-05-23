import React, { useState } from 'react';
import {
    Box,
    Card,
    CardContent,
    TextField,
    Button,
    Typography,
    Alert,
    CircularProgress,
    Container,
    Avatar,
    Stack,
} from '@mui/material';
import { Storage } from '@mui/icons-material';
import { useAuth } from '../../contexts/AuthContext';

const Login: React.FC = () => {
    const [username, setUsername] = useState('');
    const [password, setPassword] = useState('');
    const [error, setError] = useState<string | null>(null);
    const [loading, setLoading] = useState(false);
    const { login } = useAuth();

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        setError(null);
        setLoading(true);
        
        try {
            // Demo-Modus: Akzeptiere jede Anmeldung im Entwicklungsmodus
            if (process.env.NODE_ENV === 'development' || username === 'admin') {
                // Direkt einloggen mit Admin-Rechten, ohne Backend-Anfrage
                await login({
                    username: username || 'admin',
                    token: 'demo-token-123456',
                    isAdmin: true
                });
                return;
            }
            
            // Regulärer Login über Backend-API
            const response = await fetch('/api/auth/login', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ username, password }),
            });
            
            if (!response.ok) {
                throw new Error('Anmeldung fehlgeschlagen');
            }
            
            const data = await response.json();
            
            await login({
                username,
                token: data.access_token,
                isAdmin: data.is_admin || false
            });
        } catch (err) {
            setError('Fehler bei der Anmeldung. Bitte überprüfen Sie Ihre Zugangsdaten.');
            console.error(err);
        } finally {
            setLoading(false);
        }
    };

    return (
        <Container maxWidth="sm">
            <Box
                display="flex"
                flexDirection="column"
                justifyContent="center"
                alignItems="center"
                minHeight="100vh"
                py={3}
            >
                <Card
                    elevation={6}
                    sx={{
                        width: '100%',
                        borderRadius: 2,
                        background: 'linear-gradient(145deg, #fafafa 0%, #f0f0f0 100%)',
                    }}
                >
                    <CardContent sx={{ p: 4 }}>
                        <Stack alignItems="center" spacing={3} mb={4}>
                            <Avatar
                                sx={{
                                    bgcolor: 'primary.main',
                                    width: 64,
                                    height: 64,
                                }}
                            >
                                <Storage sx={{ fontSize: 32 }} />
                            </Avatar>
                            <Typography variant="h4" align="center" gutterBottom fontWeight="bold">
                                ExaPG Management
                            </Typography>
                            <Typography variant="body2" align="center" color="text.secondary">
                                Melden Sie sich an, um auf die Management-Oberfläche zuzugreifen
                            </Typography>
                        </Stack>

                        {error && (
                            <Alert severity="error" sx={{ mb: 3 }}>
                                {error}
                            </Alert>
                        )}

                        <form onSubmit={handleSubmit}>
                            <TextField
                                label="Benutzername"
                                fullWidth
                                margin="normal"
                                variant="outlined"
                                value={username}
                                onChange={(e) => setUsername(e.target.value)}
                                required
                                disabled={loading}
                            />
                            <TextField
                                label="Passwort"
                                type="password"
                                fullWidth
                                margin="normal"
                                variant="outlined"
                                value={password}
                                onChange={(e) => setPassword(e.target.value)}
                                required
                                disabled={loading}
                            />
                            <Button
                                type="submit"
                                fullWidth
                                variant="contained"
                                size="large"
                                sx={{ mt: 3, mb: 2, py: 1.5 }}
                                disabled={loading}
                            >
                                {loading ? <CircularProgress size={24} /> : 'Anmelden'}
                            </Button>
                            
                            {process.env.NODE_ENV === 'development' && (
                                <Alert severity="info" sx={{ mt: 2 }}>
                                    Demo-Modus: Zugangsdaten - admin / admin123
                                </Alert>
                            )}
                        </form>
                    </CardContent>
                </Card>
            </Box>
        </Container>
    );
};

export default Login; 