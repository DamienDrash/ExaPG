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
    CircularProgress,
} from '@mui/material';
import {
    DataGrid,
    GridColDef,
    GridActionsCellItem,
    GridRowParams,
} from '@mui/x-data-grid';
import {
    PlayArrow,
    Stop,
    Refresh,
    Visibility,
    CheckCircle,
    Error,
    Schedule,
} from '@mui/icons-material';
import { format } from 'date-fns';
import { de } from 'date-fns/locale';
import axios from 'axios';

interface ETLJob {
    job_id: number;
    job_name: string;
    enabled: boolean;
    source_type: string;
    target_schema: string;
    target_table: string;
    last_status: 'SUCCESS' | 'FAILED' | 'RUNNING' | 'never_run';
    last_run: string | null;
    rows_processed: number | null;
    duration: number | null;
}

const ETLJobs: React.FC = () => {
    const [jobs, setJobs] = useState<ETLJob[]>([]);
    const [loading, setLoading] = useState(true);
    const [runningJob, setRunningJob] = useState<number | null>(null);
    const [selectedJob, setSelectedJob] = useState<ETLJob | null>(null);
    const [detailsOpen, setDetailsOpen] = useState(false);
    const [snackbar, setSnackbar] = useState<{
        open: boolean;
        message: string;
        severity: 'success' | 'error' | 'info' | 'warning';
    }>({
        open: false,
        message: '',
        severity: 'info',
    });

    const fetchJobs = async () => {
        try {
            setLoading(true);
            const response = await axios.get('/api/etl/jobs');
            setJobs(response.data);
        } catch (error) {
            setSnackbar({
                open: true,
                message: 'Fehler beim Laden der ETL-Jobs',
                severity: 'error',
            });
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        fetchJobs();

        // Auto-refresh alle 60 Sekunden
        const interval = setInterval(fetchJobs, 60000);
        return () => clearInterval(interval);
    }, []);

    const handleRunJob = async (jobId: number) => {
        try {
            setRunningJob(jobId);
            await axios.post(`/api/etl/jobs/${jobId}/run`);
            setSnackbar({
                open: true,
                message: 'ETL-Job wurde gestartet',
                severity: 'success',
            });
            // Aktualisiere die Jobs nach kurzer Verzögerung
            setTimeout(fetchJobs, 2000);
        } catch (error) {
            setSnackbar({
                open: true,
                message: 'Fehler beim Starten des ETL-Jobs',
                severity: 'error',
            });
        } finally {
            setRunningJob(null);
        }
    };

    const handleViewDetails = (job: ETLJob) => {
        setSelectedJob(job);
        setDetailsOpen(true);
    };

    const getStatusChip = (status: string) => {
        switch (status) {
            case 'SUCCESS':
                return <Chip label="Erfolgreich" color="success" size="small" icon={<CheckCircle />} />;
            case 'FAILED':
                return <Chip label="Fehlgeschlagen" color="error" size="small" icon={<Error />} />;
            case 'RUNNING':
                return <Chip label="Läuft" color="warning" size="small" icon={<Schedule />} />;
            case 'never_run':
                return <Chip label="Nie ausgeführt" color="default" size="small" />;
            default:
                return <Chip label={status} color="default" size="small" />;
        }
    };

    const formatDuration = (seconds: number | null) => {
        if (!seconds) return 'N/A';
        if (seconds < 60) return `${Math.round(seconds)}s`;
        if (seconds < 3600) return `${Math.round(seconds / 60)}m`;
        return `${Math.round(seconds / 3600)}h`;
    };

    const formatNumber = (num: number | null) => {
        if (!num) return 'N/A';
        return new Intl.NumberFormat('de-DE').format(num);
    };

    const columns: GridColDef[] = [
        {
            field: 'job_name',
            headerName: 'Job Name',
            flex: 1,
            minWidth: 200,
        },
        {
            field: 'source_type',
            headerName: 'Quelle',
            width: 120,
        },
        {
            field: 'target',
            headerName: 'Ziel',
            width: 200,
            valueGetter: (params) => `${params.row.target_schema}.${params.row.target_table}`,
        },
        {
            field: 'last_status',
            headerName: 'Status',
            width: 140,
            renderCell: (params) => getStatusChip(params.value),
        },
        {
            field: 'last_run',
            headerName: 'Letzte Ausführung',
            width: 180,
            valueGetter: (params) => {
                if (!params.value) return 'Nie';
                return format(new Date(params.value), 'dd.MM.yyyy HH:mm', { locale: de });
            },
        },
        {
            field: 'rows_processed',
            headerName: 'Verarbeitet',
            width: 120,
            valueGetter: (params) => formatNumber(params.value),
        },
        {
            field: 'duration',
            headerName: 'Dauer',
            width: 100,
            valueGetter: (params) => formatDuration(params.value),
        },
        {
            field: 'enabled',
            headerName: 'Aktiv',
            width: 80,
            renderCell: (params) => (
                <Chip
                    label={params.value ? 'Ja' : 'Nein'}
                    color={params.value ? 'success' : 'default'}
                    size="small"
                />
            ),
        },
        {
            field: 'actions',
            type: 'actions',
            headerName: 'Aktionen',
            width: 120,
            getActions: (params: GridRowParams<ETLJob>) => [
                <GridActionsCellItem
                    icon={
                        runningJob === params.row.job_id ? (
                            <CircularProgress size={16} />
                        ) : (
                            <PlayArrow />
                        )
                    }
                    label="Ausführen"
                    onClick={() => handleRunJob(params.row.job_id)}
                    disabled={runningJob !== null}
                />,
                <GridActionsCellItem
                    icon={<Visibility />}
                    label="Details"
                    onClick={() => handleViewDetails(params.row)}
                />,
            ],
        },
    ];

    return (
        <Box>
            <Stack direction="row" justifyContent="space-between" alignItems="center" mb={3}>
                <Typography variant="h4" fontWeight="bold">
                    ETL Jobs
                </Typography>
                <Stack direction="row" spacing={2}>
                    <Button
                        variant="outlined"
                        startIcon={<Refresh />}
                        onClick={fetchJobs}
                        disabled={loading}
                    >
                        Aktualisieren
                    </Button>
                </Stack>
            </Stack>

            <Card>
                <CardContent>
                    <DataGrid
                        rows={jobs}
                        columns={columns}
                        getRowId={(row) => row.job_id}
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

            {/* Job Details Dialog */}
            <Dialog
                open={detailsOpen}
                onClose={() => setDetailsOpen(false)}
                maxWidth="md"
                fullWidth
            >
                <DialogTitle>
                    ETL Job Details: {selectedJob?.job_name}
                </DialogTitle>
                <DialogContent>
                    {selectedJob && (
                        <Stack spacing={2} mt={1}>
                            <Box>
                                <Typography variant="subtitle2" color="text.secondary">
                                    Job ID
                                </Typography>
                                <Typography variant="body1">{selectedJob.job_id}</Typography>
                            </Box>

                            <Box>
                                <Typography variant="subtitle2" color="text.secondary">
                                    Quelle
                                </Typography>
                                <Typography variant="body1">{selectedJob.source_type}</Typography>
                            </Box>

                            <Box>
                                <Typography variant="subtitle2" color="text.secondary">
                                    Ziel
                                </Typography>
                                <Typography variant="body1">
                                    {selectedJob.target_schema}.{selectedJob.target_table}
                                </Typography>
                            </Box>

                            <Box>
                                <Typography variant="subtitle2" color="text.secondary">
                                    Status
                                </Typography>
                                {getStatusChip(selectedJob.last_status)}
                            </Box>

                            <Box>
                                <Typography variant="subtitle2" color="text.secondary">
                                    Letzte Ausführung
                                </Typography>
                                <Typography variant="body1">
                                    {selectedJob.last_run
                                        ? format(new Date(selectedJob.last_run), 'dd.MM.yyyy HH:mm:ss', { locale: de })
                                        : 'Nie ausgeführt'}
                                </Typography>
                            </Box>

                            <Box>
                                <Typography variant="subtitle2" color="text.secondary">
                                    Verarbeitete Datensätze
                                </Typography>
                                <Typography variant="body1">{formatNumber(selectedJob.rows_processed)}</Typography>
                            </Box>

                            <Box>
                                <Typography variant="subtitle2" color="text.secondary">
                                    Ausführungsdauer
                                </Typography>
                                <Typography variant="body1">{formatDuration(selectedJob.duration)}</Typography>
                            </Box>

                            <Box>
                                <Typography variant="subtitle2" color="text.secondary">
                                    Aktiviert
                                </Typography>
                                <Chip
                                    label={selectedJob.enabled ? 'Ja' : 'Nein'}
                                    color={selectedJob.enabled ? 'success' : 'default'}
                                    size="small"
                                />
                            </Box>
                        </Stack>
                    )}
                </DialogContent>
                <DialogActions>
                    <Button onClick={() => setDetailsOpen(false)}>Schließen</Button>
                    {selectedJob && selectedJob.enabled && (
                        <Button
                            variant="contained"
                            startIcon={<PlayArrow />}
                            onClick={() => {
                                handleRunJob(selectedJob.job_id);
                                setDetailsOpen(false);
                            }}
                            disabled={runningJob !== null}
                        >
                            Job ausführen
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

export default ETLJobs; 