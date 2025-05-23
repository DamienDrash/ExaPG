import React, { useState, useEffect } from 'react';
import {
    Box,
    Typography,
    Button,
    Card,
    CardContent,
    Stack,
    Chip,
    IconButton,
    Alert,
    Snackbar,
    Dialog,
    DialogTitle,
    DialogContent,
    DialogActions,
    TextField,
    Tooltip,
} from '@mui/material';
import {
    DataGrid,
    GridColDef,
    GridActionsCellItem,
    GridRowParams,
} from '@mui/x-data-grid';
import {
    Refresh,
    Stop,
    Visibility,
    Search,
    Cancel,
} from '@mui/icons-material';
import { format } from 'date-fns';
import { de } from 'date-fns/locale';
import axios from 'axios';

interface ActiveQuery {
    query_id: number;
    user: string;
    application_name: string;
    client_addr: string;
    state: string;
    query: string;
    query_start: string;
    duration: number;
}

const QueryMonitor: React.FC = () => {
    const [queries, setQueries] = useState<ActiveQuery[]>([]);
    const [filteredQueries, setFilteredQueries] = useState<ActiveQuery[]>([]);
    const [loading, setLoading] = useState(true);
    const [selectedQuery, setSelectedQuery] = useState<ActiveQuery | null>(null);
    const [detailsOpen, setDetailsOpen] = useState(false);
    const [searchTerm, setSearchTerm] = useState('');
    const [snackbar, setSnackbar] = useState<{
        open: boolean;
        message: string;
        severity: 'success' | 'error' | 'info' | 'warning';
    }>({
        open: false,
        message: '',
        severity: 'info',
    });

    const fetchQueries = async () => {
        try {
            setLoading(true);
            const response = await axios.get('/api/queries/active');
            setQueries(response.data);
            setFilteredQueries(response.data);
        } catch (error) {
            setSnackbar({
                open: true,
                message: 'Fehler beim Laden der aktiven Queries',
                severity: 'error',
            });
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        fetchQueries();

        // Auto-refresh alle 10 Sekunden
        const interval = setInterval(fetchQueries, 10000);
        return () => clearInterval(interval);
    }, []);

    useEffect(() => {
        if (!searchTerm) {
            setFilteredQueries(queries);
        } else {
            const filtered = queries.filter(
                (query) =>
                    query.query.toLowerCase().includes(searchTerm.toLowerCase()) ||
                    query.user.toLowerCase().includes(searchTerm.toLowerCase()) ||
                    query.application_name.toLowerCase().includes(searchTerm.toLowerCase())
            );
            setFilteredQueries(filtered);
        }
    }, [searchTerm, queries]);

    const handleCancelQuery = async (queryId: number) => {
        try {
            await axios.post(`/api/queries/${queryId}/cancel`);
            setSnackbar({
                open: true,
                message: 'Query-Abbruch wurde angefordert',
                severity: 'info',
            });
            // Aktualisiere die Queries nach kurzer Verzögerung
            setTimeout(fetchQueries, 1000);
        } catch (error) {
            setSnackbar({
                open: true,
                message: 'Fehler beim Abbrechen der Query',
                severity: 'error',
            });
        }
    };

    const handleViewDetails = (query: ActiveQuery) => {
        setSelectedQuery(query);
        setDetailsOpen(true);
    };

    const formatDuration = (seconds: number) => {
        if (seconds < 60) return `${Math.round(seconds)}s`;
        if (seconds < 3600) return `${Math.round(seconds / 60)}m ${Math.round(seconds % 60)}s`;
        return `${Math.round(seconds / 3600)}h ${Math.round((seconds % 3600) / 60)}m`;
    };

    const getStateChip = (state: string) => {
        switch (state) {
            case 'active':
                return <Chip label="Aktiv" color="success" size="small" />;
            case 'idle':
                return <Chip label="Wartend" color="default" size="small" />;
            case 'idle in transaction':
                return <Chip label="In Transaktion" color="warning" size="small" />;
            default:
                return <Chip label={state} color="default" size="small" />;
        }
    };

    const truncateQuery = (query: string, maxLength: number = 100) => {
        if (query.length <= maxLength) return query;
        return query.substring(0, maxLength) + '...';
    };

    const columns: GridColDef[] = [
        {
            field: 'query_id',
            headerName: 'Query ID',
            width: 100,
        },
        {
            field: 'user',
            headerName: 'Benutzer',
            width: 120,
        },
        {
            field: 'application_name',
            headerName: 'Anwendung',
            width: 150,
        },
        {
            field: 'client_addr',
            headerName: 'Client IP',
            width: 120,
        },
        {
            field: 'state',
            headerName: 'Status',
            width: 120,
            renderCell: (params) => getStateChip(params.value),
        },
        {
            field: 'query',
            headerName: 'Query',
            flex: 1,
            minWidth: 300,
            renderCell: (params) => (
                <Tooltip title={params.value} placement="top">
                    <Box sx={{ overflow: 'hidden', textOverflow: 'ellipsis' }}>
                        {truncateQuery(params.value)}
                    </Box>
                </Tooltip>
            ),
        },
        {
            field: 'query_start',
            headerName: 'Gestartet',
            width: 150,
            valueGetter: (params) => format(new Date(params.value), 'HH:mm:ss', { locale: de }),
        },
        {
            field: 'duration',
            headerName: 'Dauer',
            width: 100,
            valueGetter: (params) => formatDuration(params.value),
        },
        {
            field: 'actions',
            type: 'actions',
            headerName: 'Aktionen',
            width: 120,
            getActions: (params: GridRowParams<ActiveQuery>) => [
                <GridActionsCellItem
                    icon={<Visibility />}
                    label="Details"
                    onClick={() => handleViewDetails(params.row)}
                />,
                <GridActionsCellItem
                    icon={<Cancel />}
                    label="Abbrechen"
                    onClick={() => handleCancelQuery(params.row.query_id)}
                    showInMenu
                />,
            ],
        },
    ];

    return (
        <Box>
            <Stack direction="row" justifyContent="space-between" alignItems="center" mb={3}>
                <Typography variant="h4" fontWeight="bold">
                    Query Monitor
                </Typography>
                <Stack direction="row" spacing={2}>
                    <TextField
                        size="small"
                        placeholder="Query, Benutzer oder Anwendung suchen..."
                        value={searchTerm}
                        onChange={(e) => setSearchTerm(e.target.value)}
                        InputProps={{
                            startAdornment: <Search sx={{ mr: 1, color: 'text.secondary' }} />,
                        }}
                        sx={{ width: 300 }}
                    />
                    <Button
                        variant="outlined"
                        startIcon={<Refresh />}
                        onClick={fetchQueries}
                        disabled={loading}
                    >
                        Aktualisieren
                    </Button>
                </Stack>
            </Stack>

            <Card>
                <CardContent>
                    <Stack direction="row" justifyContent="space-between" alignItems="center" mb={2}>
                        <Typography variant="h6">
                            Aktive Queries ({filteredQueries.length})
                        </Typography>
                        <Typography variant="body2" color="text.secondary">
                            Automatische Aktualisierung alle 10 Sekunden
                        </Typography>
                    </Stack>

                    <DataGrid
                        rows={filteredQueries}
                        columns={columns}
                        getRowId={(row) => row.query_id}
                        loading={loading}
                        autoHeight
                        disableRowSelectionOnClick
                        pageSizeOptions={[10, 25, 50]}
                        initialState={{
                            pagination: {
                                paginationModel: { pageSize: 25 },
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

            {/* Query Details Dialog */}
            <Dialog
                open={detailsOpen}
                onClose={() => setDetailsOpen(false)}
                maxWidth="lg"
                fullWidth
            >
                <DialogTitle>
                    Query Details (ID: {selectedQuery?.query_id})
                </DialogTitle>
                <DialogContent>
                    {selectedQuery && (
                        <Stack spacing={3} mt={1}>
                            <Box>
                                <Typography variant="subtitle2" color="text.secondary" gutterBottom>
                                    Benutzer & Verbindung
                                </Typography>
                                <Stack direction="row" spacing={4}>
                                    <Box>
                                        <Typography variant="body2" color="text.secondary">Benutzer</Typography>
                                        <Typography variant="body1">{selectedQuery.user}</Typography>
                                    </Box>
                                    <Box>
                                        <Typography variant="body2" color="text.secondary">Anwendung</Typography>
                                        <Typography variant="body1">{selectedQuery.application_name || 'N/A'}</Typography>
                                    </Box>
                                    <Box>
                                        <Typography variant="body2" color="text.secondary">Client IP</Typography>
                                        <Typography variant="body1">{selectedQuery.client_addr || 'N/A'}</Typography>
                                    </Box>
                                </Stack>
                            </Box>

                            <Box>
                                <Typography variant="subtitle2" color="text.secondary" gutterBottom>
                                    Ausführungsdetails
                                </Typography>
                                <Stack direction="row" spacing={4}>
                                    <Box>
                                        <Typography variant="body2" color="text.secondary">Status</Typography>
                                        {getStateChip(selectedQuery.state)}
                                    </Box>
                                    <Box>
                                        <Typography variant="body2" color="text.secondary">Gestartet</Typography>
                                        <Typography variant="body1">
                                            {format(new Date(selectedQuery.query_start), 'dd.MM.yyyy HH:mm:ss', { locale: de })}
                                        </Typography>
                                    </Box>
                                    <Box>
                                        <Typography variant="body2" color="text.secondary">Laufzeit</Typography>
                                        <Typography variant="body1">{formatDuration(selectedQuery.duration)}</Typography>
                                    </Box>
                                </Stack>
                            </Box>

                            <Box>
                                <Typography variant="subtitle2" color="text.secondary" gutterBottom>
                                    SQL Query
                                </Typography>
                                <TextField
                                    multiline
                                    rows={12}
                                    fullWidth
                                    value={selectedQuery.query}
                                    InputProps={{
                                        readOnly: true,
                                    }}
                                    sx={{
                                        '& .MuiInputBase-input': {
                                            fontFamily: 'monospace',
                                            fontSize: '0.875rem',
                                        },
                                    }}
                                />
                            </Box>
                        </Stack>
                    )}
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => setDetailsOpen(false)}>Schließen</Button>
                    {selectedQuery && (
                        <Button
                            variant="outlined"
                            color="error"
                            startIcon={<Cancel />}
                            onClick={() => {
                                handleCancelQuery(selectedQuery.query_id);
                                setDetailsOpen(false);
                            }}
                        >
                            Query abbrechen
                        </Button>
                    )}
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

export default QueryMonitor; 