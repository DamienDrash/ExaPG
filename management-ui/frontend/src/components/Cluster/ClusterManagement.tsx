import React, { useState, useEffect } from 'react';
import {
    Box,
    Typography,
    Button,
    Card,
    CardContent,
    Stack,
    Chip,
    Grid,
    Paper,
    LinearProgress,
    Alert,
    Snackbar,
} from '@mui/material';
import {
    DataGrid,
    GridColDef,
} from '@mui/x-data-grid';
import {
    Refresh,
    Computer,
    CheckCircle,
    Error,
    Warning,
    Memory,
    Storage as StorageIcon,
} from '@mui/icons-material';
import { format } from 'date-fns';
import { de } from 'date-fns/locale';
import axios from 'axios';

interface ClusterNode {
    node_id: string;
    hostname: string;
    port: number;
    role: 'coordinator' | 'worker' | 'standby';
    status: 'online' | 'offline' | 'maintenance';
    last_heartbeat: string;
}

interface ClusterMetrics {
    total_nodes: number;
    online_nodes: number;
    offline_nodes: number;
    cpu_avg: number;
    memory_avg: number;
    disk_avg: number;
}

const ClusterManagement: React.FC = () => {
    const [nodes, setNodes] = useState<ClusterNode[]>([]);
    const [metrics, setMetrics] = useState<ClusterMetrics>({
        total_nodes: 0,
        online_nodes: 0,
        offline_nodes: 0,
        cpu_avg: 0,
        memory_avg: 0,
        disk_avg: 0,
    });
    const [loading, setLoading] = useState(true);
    const [snackbar, setSnackbar] = useState<{
        open: boolean;
        message: string;
        severity: 'success' | 'error' | 'info' | 'warning';
    }>({
        open: false,
        message: '',
        severity: 'info',
    });

    const fetchClusterData = async () => {
        try {
            setLoading(true);
            const response = await axios.get('/api/cluster/nodes');
            const nodeData = response.data;
            setNodes(nodeData);

            // Berechne Cluster-Metriken
            const totalNodes = nodeData.length;
            const onlineNodes = nodeData.filter((node: ClusterNode) => node.status === 'online').length;
            const offlineNodes = totalNodes - onlineNodes;

            setMetrics({
                total_nodes: totalNodes,
                online_nodes: onlineNodes,
                offline_nodes: offlineNodes,
                cpu_avg: Math.random() * 100, // Mock-Daten
                memory_avg: Math.random() * 100,
                disk_avg: Math.random() * 100,
            });
        } catch (error) {
            // Wenn keine Knoten konfiguriert sind, erstelle Mock-Daten
            const mockNodes: ClusterNode[] = [
                {
                    node_id: 'coordinator-1',
                    hostname: 'exapg-coordinator',
                    port: 5432,
                    role: 'coordinator',
                    status: 'online',
                    last_heartbeat: new Date().toISOString(),
                },
                {
                    node_id: 'worker-1',
                    hostname: 'exapg-worker-1',
                    port: 5432,
                    role: 'worker',
                    status: 'online',
                    last_heartbeat: new Date(Date.now() - 30000).toISOString(),
                },
                {
                    node_id: 'worker-2',
                    hostname: 'exapg-worker-2',
                    port: 5432,
                    role: 'worker',
                    status: 'online',
                    last_heartbeat: new Date(Date.now() - 45000).toISOString(),
                },
            ];

            setNodes(mockNodes);
            setMetrics({
                total_nodes: 3,
                online_nodes: 3,
                offline_nodes: 0,
                cpu_avg: 45,
                memory_avg: 67,
                disk_avg: 32,
            });

            setSnackbar({
                open: true,
                message: 'Mock-Cluster-Daten werden angezeigt (keine realen Knoten konfiguriert)',
                severity: 'info',
            });
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        fetchClusterData();

        // Auto-refresh alle 30 Sekunden
        const interval = setInterval(fetchClusterData, 30000);
        return () => clearInterval(interval);
    }, []);

    const getStatusChip = (status: string) => {
        switch (status) {
            case 'online':
                return <Chip label="Online" color="success" size="small" icon={<CheckCircle />} />;
            case 'offline':
                return <Chip label="Offline" color="error" size="small" icon={<Error />} />;
            case 'maintenance':
                return <Chip label="Wartung" color="warning" size="small" icon={<Warning />} />;
            default:
                return <Chip label={status} color="default" size="small" />;
        }
    };

    const getRoleChip = (role: string) => {
        switch (role) {
            case 'coordinator':
                return <Chip label="Koordinator" color="primary" size="small" />;
            case 'worker':
                return <Chip label="Worker" color="secondary" size="small" />;
            case 'standby':
                return <Chip label="Standby" color="default" size="small" />;
            default:
                return <Chip label={role} color="default" size="small" />;
        }
    };

    const getProgressColor = (value: number) => {
        if (value < 60) return 'success';
        if (value < 80) return 'warning';
        return 'error';
    };

    const columns: GridColDef[] = [
        {
            field: 'node_id',
            headerName: 'Node ID',
            width: 150,
        },
        {
            field: 'hostname',
            headerName: 'Hostname',
            width: 200,
        },
        {
            field: 'port',
            headerName: 'Port',
            width: 100,
        },
        {
            field: 'role',
            headerName: 'Rolle',
            width: 130,
            renderCell: (params) => getRoleChip(params.value),
        },
        {
            field: 'status',
            headerName: 'Status',
            width: 120,
            renderCell: (params) => getStatusChip(params.value),
        },
        {
            field: 'last_heartbeat',
            headerName: 'Letzter Heartbeat',
            width: 180,
            valueGetter: (params) => format(new Date(params.value), 'dd.MM.yyyy HH:mm:ss', { locale: de }),
        },
    ];

    return (
        <Box>
            <Stack direction="row" justifyContent="space-between" alignItems="center" mb={3}>
                <Typography variant="h4" fontWeight="bold">
                    Cluster Management
                </Typography>
                <Button
                    variant="outlined"
                    startIcon={<Refresh />}
                    onClick={fetchClusterData}
                    disabled={loading}
                >
                    Aktualisieren
                </Button>
            </Stack>

            {/* Cluster Overview */}
            <Grid container spacing={3} mb={4}>
                <Grid item xs={12} md={3}>
                    <Card>
                        <CardContent>
                            <Stack direction="row" alignItems="center" justifyContent="space-between">
                                <Box>
                                    <Typography color="text.secondary" gutterBottom variant="body2">
                                        Gesamt Knoten
                                    </Typography>
                                    <Typography variant="h4" fontWeight="bold">
                                        {metrics.total_nodes}
                                    </Typography>
                                </Box>
                                <Computer color="primary" sx={{ fontSize: 40 }} />
                            </Stack>
                        </CardContent>
                    </Card>
                </Grid>

                <Grid item xs={12} md={3}>
                    <Card>
                        <CardContent>
                            <Stack direction="row" alignItems="center" justifyContent="space-between">
                                <Box>
                                    <Typography color="text.secondary" gutterBottom variant="body2">
                                        Online Knoten
                                    </Typography>
                                    <Typography variant="h4" fontWeight="bold" color="success.main">
                                        {metrics.online_nodes}
                                    </Typography>
                                </Box>
                                <CheckCircle color="success" sx={{ fontSize: 40 }} />
                            </Stack>
                        </CardContent>
                    </Card>
                </Grid>

                <Grid item xs={12} md={3}>
                    <Card>
                        <CardContent>
                            <Stack direction="row" alignItems="center" justifyContent="space-between">
                                <Box>
                                    <Typography color="text.secondary" gutterBottom variant="body2">
                                        Offline Knoten
                                    </Typography>
                                    <Typography variant="h4" fontWeight="bold" color={metrics.offline_nodes > 0 ? "error.main" : "text.primary"}>
                                        {metrics.offline_nodes}
                                    </Typography>
                                </Box>
                                <Error color={metrics.offline_nodes > 0 ? "error" : "disabled"} sx={{ fontSize: 40 }} />
                            </Stack>
                        </CardContent>
                    </Card>
                </Grid>

                <Grid item xs={12} md={3}>
                    <Card>
                        <CardContent>
                            <Stack direction="row" alignItems="center" justifyContent="space-between">
                                <Box>
                                    <Typography color="text.secondary" gutterBottom variant="body2">
                                        Cluster-Health
                                    </Typography>
                                    <Typography variant="h6" fontWeight="bold">
                                        {metrics.offline_nodes === 0 ? 'Gesund' : 'Warnung'}
                                    </Typography>
                                </Box>
                                <Box
                                    sx={{
                                        width: 40,
                                        height: 40,
                                        borderRadius: '50%',
                                        bgcolor: metrics.offline_nodes === 0 ? 'success.main' : 'warning.main',
                                        display: 'flex',
                                        alignItems: 'center',
                                        justifyContent: 'center',
                                    }}
                                >
                                    {metrics.offline_nodes === 0 ? (
                                        <CheckCircle sx={{ color: 'white' }} />
                                    ) : (
                                        <Warning sx={{ color: 'white' }} />
                                    )}
                                </Box>
                            </Stack>
                        </CardContent>
                    </Card>
                </Grid>
            </Grid>

            {/* Resource Usage */}
            <Grid container spacing={3} mb={4}>
                <Grid item xs={12} md={4}>
                    <Card>
                        <CardContent>
                            <Stack spacing={2}>
                                <Typography variant="h6" gutterBottom>
                                    CPU Auslastung
                                </Typography>
                                <Box>
                                    <Stack direction="row" justifyContent="space-between" alignItems="center" mb={1}>
                                        <Typography variant="body2" color="text.secondary">
                                            Durchschnitt
                                        </Typography>
                                        <Typography variant="body2" fontWeight="bold">
                                            {Math.round(metrics.cpu_avg)}%
                                        </Typography>
                                    </Stack>
                                    <LinearProgress
                                        variant="determinate"
                                        value={metrics.cpu_avg}
                                        color={getProgressColor(metrics.cpu_avg)}
                                        sx={{ height: 8, borderRadius: 4 }}
                                    />
                                </Box>
                            </Stack>
                        </CardContent>
                    </Card>
                </Grid>

                <Grid item xs={12} md={4}>
                    <Card>
                        <CardContent>
                            <Stack spacing={2}>
                                <Typography variant="h6" gutterBottom>
                                    Memory Auslastung
                                </Typography>
                                <Box>
                                    <Stack direction="row" justifyContent="space-between" alignItems="center" mb={1}>
                                        <Typography variant="body2" color="text.secondary">
                                            Durchschnitt
                                        </Typography>
                                        <Typography variant="body2" fontWeight="bold">
                                            {Math.round(metrics.memory_avg)}%
                                        </Typography>
                                    </Stack>
                                    <LinearProgress
                                        variant="determinate"
                                        value={metrics.memory_avg}
                                        color={getProgressColor(metrics.memory_avg)}
                                        sx={{ height: 8, borderRadius: 4 }}
                                    />
                                </Box>
                            </Stack>
                        </CardContent>
                    </Card>
                </Grid>

                <Grid item xs={12} md={4}>
                    <Card>
                        <CardContent>
                            <Stack spacing={2}>
                                <Typography variant="h6" gutterBottom>
                                    Disk Auslastung
                                </Typography>
                                <Box>
                                    <Stack direction="row" justifyContent="space-between" alignItems="center" mb={1}>
                                        <Typography variant="body2" color="text.secondary">
                                            Durchschnitt
                                        </Typography>
                                        <Typography variant="body2" fontWeight="bold">
                                            {Math.round(metrics.disk_avg)}%
                                        </Typography>
                                    </Stack>
                                    <LinearProgress
                                        variant="determinate"
                                        value={metrics.disk_avg}
                                        color={getProgressColor(metrics.disk_avg)}
                                        sx={{ height: 8, borderRadius: 4 }}
                                    />
                                </Box>
                            </Stack>
                        </CardContent>
                    </Card>
                </Grid>
            </Grid>

            {/* Nodes Table */}
            <Card>
                <CardContent>
                    <Typography variant="h6" gutterBottom>
                        Cluster Knoten
                    </Typography>
                    <DataGrid
                        rows={nodes}
                        columns={columns}
                        getRowId={(row) => row.node_id}
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

export default ClusterManagement; 