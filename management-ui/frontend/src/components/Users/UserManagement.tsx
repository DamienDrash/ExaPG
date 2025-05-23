import React, { useState, useEffect } from 'react';
import {
    Box,
    Typography,
    Button,
    Card,
    CardContent,
    Stack,
    Chip,
    Dialog,
    DialogTitle,
    DialogContent,
    DialogActions,
    TextField,
    FormControlLabel,
    Switch,
    Alert,
    Snackbar,
} from '@mui/material';
import {
    DataGrid,
    GridColDef,
    GridActionsCellItem,
    GridRowParams,
} from '@mui/x-data-grid';
import {
    Add,
    Edit,
    Delete,
    Refresh,
    AdminPanelSettings,
    Person,
} from '@mui/icons-material';
import { format } from 'date-fns';
import { de } from 'date-fns/locale';
import axios from 'axios';
import { useAuth } from '../../contexts/AuthContext';

interface User {
    username: string;
    email?: string;
    is_admin: boolean;
}

interface UserForm {
    username: string;
    password: string;
    email: string;
    is_admin: boolean;
}

const UserManagement: React.FC = () => {
    const [users, setUsers] = useState<User[]>([]);
    const [loading, setLoading] = useState(true);
    const [dialogOpen, setDialogOpen] = useState(false);
    const [editingUser, setEditingUser] = useState<User | null>(null);
    const [userForm, setUserForm] = useState<UserForm>({
        username: '',
        password: '',
        email: '',
        is_admin: false,
    });
    const [formErrors, setFormErrors] = useState<Record<string, string>>({});
    const [snackbar, setSnackbar] = useState<{
        open: boolean;
        message: string;
        severity: 'success' | 'error' | 'info' | 'warning';
    }>({
        open: false,
        message: '',
        severity: 'info',
    });

    const { user: currentUser } = useAuth();

    const fetchUsers = async () => {
        try {
            setLoading(true);
            const response = await axios.get('/api/users');
            setUsers(response.data);
        } catch (error) {
            setSnackbar({
                open: true,
                message: 'Fehler beim Laden der Benutzer',
                severity: 'error',
            });
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        fetchUsers();
    }, []);

    const handleAddUser = () => {
        setEditingUser(null);
        setUserForm({
            username: '',
            password: '',
            email: '',
            is_admin: false,
        });
        setFormErrors({});
        setDialogOpen(true);
    };

    const handleEditUser = (user: User) => {
        setEditingUser(user);
        setUserForm({
            username: user.username,
            password: '', // Passwort wird beim Bearbeiten nicht angezeigt
            email: user.email || '',
            is_admin: user.is_admin,
        });
        setFormErrors({});
        setDialogOpen(true);
    };

    const validateForm = (): boolean => {
        const errors: Record<string, string> = {};

        if (!userForm.username.trim()) {
            errors.username = 'Benutzername ist erforderlich';
        }

        if (!editingUser && !userForm.password.trim()) {
            errors.password = 'Passwort ist erforderlich für neue Benutzer';
        }

        if (userForm.password && userForm.password.length < 6) {
            errors.password = 'Passwort muss mindestens 6 Zeichen lang sein';
        }

        if (userForm.email && !/\S+@\S+\.\S+/.test(userForm.email)) {
            errors.email = 'Ungültige E-Mail-Adresse';
        }

        setFormErrors(errors);
        return Object.keys(errors).length === 0;
    };

    const handleSaveUser = async () => {
        if (!validateForm()) {
            return;
        }

        try {
            if (editingUser) {
                // Bearbeitung wird in dieser Demo nicht implementiert
                setSnackbar({
                    open: true,
                    message: 'Benutzer-Bearbeitung ist in dieser Demo nicht verfügbar',
                    severity: 'info',
                });
            } else {
                // Neuen Benutzer erstellen
                await axios.post('/api/users', {
                    username: userForm.username,
                    password: userForm.password,
                    email: userForm.email || undefined,
                    is_admin: userForm.is_admin,
                });

                setSnackbar({
                    open: true,
                    message: 'Benutzer wurde erfolgreich erstellt',
                    severity: 'success',
                });

                fetchUsers();
            }

            setDialogOpen(false);
        } catch (error: any) {
            setSnackbar({
                open: true,
                message: error.response?.data?.detail || 'Fehler beim Speichern des Benutzers',
                severity: 'error',
            });
        }
    };

    const handleDeleteUser = async (username: string) => {
        if (username === currentUser?.username) {
            setSnackbar({
                open: true,
                message: 'Sie können sich nicht selbst löschen',
                severity: 'warning',
            });
            return;
        }

        setSnackbar({
            open: true,
            message: `Benutzer-Löschung für "${username}" ist in dieser Demo nicht verfügbar`,
            severity: 'info',
        });
    };

    const columns: GridColDef[] = [
        {
            field: 'username',
            headerName: 'Benutzername',
            flex: 1,
            minWidth: 150,
        },
        {
            field: 'email',
            headerName: 'E-Mail',
            flex: 1,
            minWidth: 200,
            valueGetter: (params) => params.value || 'Nicht angegeben',
        },
        {
            field: 'is_admin',
            headerName: 'Administrator',
            width: 140,
            renderCell: (params) => (
                <Chip
                    label={params.value ? 'Admin' : 'Benutzer'}
                    color={params.value ? 'primary' : 'default'}
                    size="small"
                    icon={params.value ? <AdminPanelSettings /> : <Person />}
                />
            ),
        },
        {
            field: 'actions',
            type: 'actions',
            headerName: 'Aktionen',
            width: 120,
            getActions: (params: GridRowParams<User>) => [
                <GridActionsCellItem
                    icon={<Edit />}
                    label="Bearbeiten"
                    onClick={() => handleEditUser(params.row)}
                />,
                <GridActionsCellItem
                    icon={<Delete />}
                    label="Löschen"
                    onClick={() => handleDeleteUser(params.row.username)}
                    disabled={params.row.username === currentUser?.username}
                    showInMenu
                />,
            ],
        },
    ];

    return (
        <Box>
            <Stack direction="row" justifyContent="space-between" alignItems="center" mb={3}>
                <Typography variant="h4" fontWeight="bold">
                    Benutzer-Verwaltung
                </Typography>
                <Stack direction="row" spacing={2}>
                    <Button
                        variant="contained"
                        startIcon={<Add />}
                        onClick={handleAddUser}
                    >
                        Benutzer hinzufügen
                    </Button>
                    <Button
                        variant="outlined"
                        startIcon={<Refresh />}
                        onClick={fetchUsers}
                        disabled={loading}
                    >
                        Aktualisieren
                    </Button>
                </Stack>
            </Stack>

            <Card>
                <CardContent>
                    <Typography variant="h6" gutterBottom>
                        Alle Benutzer ({users.length})
                    </Typography>
                    <DataGrid
                        rows={users}
                        columns={columns}
                        getRowId={(row) => row.username}
                        loading={loading}
                        autoHeight
                        disableRowSelectionOnClick
                        pageSizeOptions={[10, 25, 50]}
                        initialState={{
                            pagination: {
                                paginationModel: { pageSize: 10 },
                            },
                        }}
                        sx={{
                            '& .MuiDataGrid-row:hover': {
                                backgroundColor: 'action.hover',
                            },
                        }}
                    />
                </CardContent>
            </Card>

            {/* User Form Dialog */}
            <Dialog
                open={dialogOpen}
                onClose={() => setDialogOpen(false)}
                maxWidth="sm"
                fullWidth
            >
                <DialogTitle>
                    {editingUser ? 'Benutzer bearbeiten' : 'Neuen Benutzer hinzufügen'}
                </DialogTitle>
                <DialogContent>
                    <Stack spacing={3} mt={1}>
                        <TextField
                            label="Benutzername"
                            value={userForm.username}
                            onChange={(e) => setUserForm({ ...userForm, username: e.target.value })}
                            error={!!formErrors.username}
                            helperText={formErrors.username}
                            fullWidth
                            disabled={!!editingUser} // Benutzername kann nicht geändert werden
                        />

                        <TextField
                            label="Passwort"
                            type="password"
                            value={userForm.password}
                            onChange={(e) => setUserForm({ ...userForm, password: e.target.value })}
                            error={!!formErrors.password}
                            helperText={formErrors.password || (editingUser ? 'Leer lassen, um Passwort nicht zu ändern' : '')}
                            fullWidth
                        />

                        <TextField
                            label="E-Mail (optional)"
                            type="email"
                            value={userForm.email}
                            onChange={(e) => setUserForm({ ...userForm, email: e.target.value })}
                            error={!!formErrors.email}
                            helperText={formErrors.email}
                            fullWidth
                        />

                        <FormControlLabel
                            control={
                                <Switch
                                    checked={userForm.is_admin}
                                    onChange={(e) => setUserForm({ ...userForm, is_admin: e.target.checked })}
                                />
                            }
                            label="Administrator-Berechtigung"
                        />

                        {userForm.is_admin && (
                            <Alert severity="warning">
                                Administrator-Benutzer haben vollen Zugriff auf alle Funktionen der Management-UI.
                            </Alert>
                        )}
                    </Stack>
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => setDialogOpen(false)}>
                        Abbrechen
                    </Button>
                    <Button
                        variant="contained"
                        onClick={handleSaveUser}
                    >
                        {editingUser ? 'Aktualisieren' : 'Erstellen'}
                    </Button>
                </DialogActions>
            </Dialog>

            {/* Snackbar for notifications */}
            <Snackbar
                open={snackbar.open}
                autoHideDuration={6000}
                onClose={() => setSnackbar({ ...snackbar, open: false })}
            >
                <Alert
                    onClose={() => setSnackbar({ ...snackbar, open: false })}
                    severity={snackbar.severity}
                    sx={{ width: '100%' }}
                >
                    {snackbar.message}
                </Alert>
            </Snackbar>
        </Box>
    );
};

export default UserManagement; 