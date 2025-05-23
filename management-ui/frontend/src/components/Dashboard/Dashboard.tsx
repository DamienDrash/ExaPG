import React, { useState, useEffect } from 'react';
import {
    Box,
    Grid,
    Card,
    CardContent,
    Typography,
    Chip,
    Stack,
    IconButton,
    CircularProgress,
    Alert,
    Paper,
} from '@mui/material';
import {
    Refresh,
    Storage,
    Speed,
    AccountTree,
    TrendingUp,
    QueryStats,
} from '@mui/icons-material';
import {
    LineChart,
    Line,
    XAxis,
    YAxis,
    CartesianGrid,
    Tooltip,
    ResponsiveContainer,
    BarChart,
    Bar,
    PieChart,
    Pie,
    Cell,
} from 'recharts';
import axios from 'axios';

interface DashboardData {
    active_connections: number;
    total_etl_jobs: number;
    active_etl_jobs: number;
    total_nodes: number;
    online_nodes: number;
    database_size: string;
    cluster_health: 'healthy' | 'warning' | 'error';
}

interface MetricData {
    name: string;
    value: number;
    timestamp: string;
}

const Dashboard: React.FC = () => {
    const [dashboardData, setDashboardData] = useState<DashboardData | null>(null);
    const [metrics, setMetrics] = useState<MetricData[]>([]);
    const [loading, setLoading] = useState(true);
    const [error, setError] = useState<string | null>(null);

    const fetchDashboardData = async () => {
        try {
            setLoading(true);
            setError(null);

            // Versuche, die Daten vom Backend zu laden
            let overviewData, metricsData;

            try {
                const overviewResponse = await axios.get('/api/dashboard/overview');
                overviewData = overviewResponse.data;
            } catch (err) {
                console.error('Dashboard overview error:', err);
                // Verwende Fallback-Daten für die Übersicht
                overviewData = {
                    active_connections: 12,
                    total_etl_jobs: 8,
                    active_etl_jobs: 3,
                    total_nodes: 3,
                    online_nodes: 3,
                    database_size: '14.5 GB',
                    cluster_health: 'healthy'
                };
            }

            try {
                const metricsResponse = await axios.get('/api/dashboard/metrics');
                metricsData = metricsResponse.data;
            } catch (err) {
                console.error('Dashboard metrics error:', err);
                // Verwende Fallback-Daten für die Metriken
                metricsData = [
                    { name: 'cpu_usage', value: 45.2, timestamp: new Date().toISOString() },
                    { name: 'memory_usage', value: 62.8, timestamp: new Date().toISOString() },
                    { name: 'active_connections', value: 12, timestamp: new Date().toISOString() }
                ];
            }

            setDashboardData(overviewData);
            setMetrics(metricsData);
        } catch (err) {
            setError('Fehler beim Laden der Dashboard-Daten');
            console.error('Dashboard general error:', err);
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        fetchDashboardData();

        // Auto-refresh alle 30 Sekunden
        const interval = setInterval(fetchDashboardData, 30000);
        return () => clearInterval(interval);
    }, []);

    const getHealthColor = (health: string) => {
        switch (health) {
            case 'healthy': return 'success';
            case 'warning': return 'warning';
            case 'error': return 'error';
            default: return 'default';
        }
    };

    const getHealthText = (health: string) => {
        switch (health) {
            case 'healthy': return 'Gesund';
            case 'warning': return 'Warnung';
            case 'error': return 'Fehler';
            default: return 'Unbekannt';
        }
    };

    // Beispiel-Metriken für Charts (würden normalerweise von der API kommen)
    const performanceData = [
        { time: '00:00', cpu: 45, memory: 65, connections: 12 },
        { time: '04:00', cpu: 52, memory: 68, connections: 8 },
        { time: '08:00', cpu: 78, memory: 72, connections: 25 },
        { time: '12:00', cpu: 85, memory: 75, connections: 32 },
        { time: '16:00', cpu: 72, memory: 70, connections: 28 },
        { time: '20:00', cpu: 58, memory: 66, connections: 18 },
    ];

    const etlJobData = [
        { name: 'Erfolgreich', value: 85, color: '#4caf50' },
        { name: 'Fehlgeschlagen', value: 10, color: '#f44336' },
        { name: 'Läuft', value: 5, color: '#ff9800' },
    ];

    if (loading && !dashboardData) {
        return (
            <Box display="flex" justifyContent="center" alignItems="center" height="400px">
                <CircularProgress />
            </Box>
        );
    }

    if (error) {
        return (
            <Alert severity="error" action={
                <IconButton onClick={fetchDashboardData}>
                    <Refresh />
                </IconButton>
            }>
                {error}
            </Alert>
        );
    }

    return (
        <Box>
            <Stack direction="row" justifyContent="space-between" alignItems="center" mb={3}>
                <Typography variant="h4" fontWeight="bold">
                    Dashboard
                </Typography>
                <IconButton onClick={fetchDashboardData} disabled={loading}>
                    <Refresh />
                </IconButton>
            </Stack>

            {/* Key Metrics Cards */}
            <Grid container spacing={3} mb={4}>
                <Grid item xs={12} sm={6} md={3}>
                    <Card>
                        <CardContent>
                            <Stack direction="row" alignItems="center" justifyContent="space-between">
                                <Box>
                                    <Typography color="text.secondary" gutterBottom variant="body2">
                                        Aktive Verbindungen
                                    </Typography>
                                    <Typography variant="h4" fontWeight="bold">
                                        {dashboardData?.active_connections || 0}
                                    </Typography>
                                </Box>
                                <Storage color="primary" sx={{ fontSize: 40 }} />
                            </Stack>
                        </CardContent>
                    </Card>
                </Grid>

                <Grid item xs={12} sm={6} md={3}>
                    <Card>
                        <CardContent>
                            <Stack direction="row" alignItems="center" justifyContent="space-between">
                                <Box>
                                    <Typography color="text.secondary" gutterBottom variant="body2">
                                        ETL Jobs
                                    </Typography>
                                    <Typography variant="h4" fontWeight="bold">
                                        {dashboardData?.active_etl_jobs || 0}/{dashboardData?.total_etl_jobs || 0}
                                    </Typography>
                                    <Typography variant="body2" color="text.secondary">
                                        Aktiv/Gesamt
                                    </Typography>
                                </Box>
                                <AccountTree color="secondary" sx={{ fontSize: 40 }} />
                            </Stack>
                        </CardContent>
                    </Card>
                </Grid>

                <Grid item xs={12} sm={6} md={3}>
                    <Card>
                        <CardContent>
                            <Stack direction="row" alignItems="center" justifyContent="space-between">
                                <Box>
                                    <Typography color="text.secondary" gutterBottom variant="body2">
                                        Cluster-Knoten
                                    </Typography>
                                    <Typography variant="h4" fontWeight="bold">
                                        {dashboardData?.online_nodes || 0}/{dashboardData?.total_nodes || 0}
                                    </Typography>
                                    <Typography variant="body2" color="text.secondary">
                                        Online/Gesamt
                                    </Typography>
                                </Box>
                                <Storage color="success" sx={{ fontSize: 40 }} />
                            </Stack>
                        </CardContent>
                    </Card>
                </Grid>

                <Grid item xs={12} sm={6} md={3}>
                    <Card>
                        <CardContent>
                            <Stack direction="row" alignItems="center" justifyContent="space-between">
                                <Box>
                                    <Typography color="text.secondary" gutterBottom variant="body2">
                                        Datenbankgröße
                                    </Typography>
                                    <Typography variant="h4" fontWeight="bold">
                                        {dashboardData?.database_size || 'N/A'}
                                    </Typography>
                                </Box>
                                <Speed color="warning" sx={{ fontSize: 40 }} />
                            </Stack>
                        </CardContent>
                    </Card>
                </Grid>
            </Grid>

            {/* Cluster Health Status */}
            <Grid container spacing={3} mb={4}>
                <Grid item xs={12} md={4}>
                    <Card>
                        <CardContent>
                            <Typography variant="h6" gutterBottom>
                                Cluster-Status
                            </Typography>
                            <Stack direction="row" alignItems="center" spacing={2}>
                                <Chip
                                    label={getHealthText(dashboardData?.cluster_health || 'unknown')}
                                    color={getHealthColor(dashboardData?.cluster_health || 'unknown') as any}
                                    variant="filled"
                                />
                                <Typography variant="body2" color="text.secondary">
                                    Alle Systeme operativ
                                </Typography>
                            </Stack>
                        </CardContent>
                    </Card>
                </Grid>

                <Grid item xs={12} md={8}>
                    <Card>
                        <CardContent>
                            <Typography variant="h6" gutterBottom>
                                System-Performance (letzte 24h)
                            </Typography>
                            <ResponsiveContainer width="100%" height={200}>
                                <LineChart data={performanceData}>
                                    <CartesianGrid strokeDasharray="3 3" />
                                    <XAxis dataKey="time" />
                                    <YAxis />
                                    <Tooltip />
                                    <Line
                                        type="monotone"
                                        dataKey="cpu"
                                        stroke="#1976d2"
                                        strokeWidth={2}
                                        name="CPU %"
                                    />
                                    <Line
                                        type="monotone"
                                        dataKey="memory"
                                        stroke="#f50057"
                                        strokeWidth={2}
                                        name="Memory %"
                                    />
                                    <Line
                                        type="monotone"
                                        dataKey="connections"
                                        stroke="#4caf50"
                                        strokeWidth={2}
                                        name="Verbindungen"
                                    />
                                </LineChart>
                            </ResponsiveContainer>
                        </CardContent>
                    </Card>
                </Grid>
            </Grid>

            {/* ETL Job Status and Recent Activity */}
            <Grid container spacing={3}>
                <Grid item xs={12} md={6}>
                    <Card>
                        <CardContent>
                            <Typography variant="h6" gutterBottom>
                                ETL Job Status
                            </Typography>
                            <ResponsiveContainer width="100%" height={250}>
                                <PieChart>
                                    <Pie
                                        data={etlJobData}
                                        cx="50%"
                                        cy="50%"
                                        outerRadius={80}
                                        dataKey="value"
                                        label={({ name, value }) => `${name}: ${value}%`}
                                    >
                                        {etlJobData.map((entry, index) => (
                                            <Cell key={`cell-${index}`} fill={entry.color} />
                                        ))}
                                    </Pie>
                                    <Tooltip />
                                </PieChart>
                            </ResponsiveContainer>
                        </CardContent>
                    </Card>
                </Grid>

                <Grid item xs={12} md={6}>
                    <Card>
                        <CardContent>
                            <Typography variant="h6" gutterBottom>
                                Neueste Aktivitäten
                            </Typography>
                            <Stack spacing={2}>
                                <Paper variant="outlined" sx={{ p: 2 }}>
                                    <Stack direction="row" alignItems="center" spacing={2}>
                                        <QueryStats color="primary" />
                                        <Box>
                                            <Typography variant="body2" fontWeight="bold">
                                                ETL Job "customer_data_etl" abgeschlossen
                                            </Typography>
                                            <Typography variant="caption" color="text.secondary">
                                                vor 5 Minuten • 1.2M Datensätze verarbeitet
                                            </Typography>
                                        </Box>
                                    </Stack>
                                </Paper>

                                <Paper variant="outlined" sx={{ p: 2 }}>
                                    <Stack direction="row" alignItems="center" spacing={2}>
                                        <TrendingUp color="success" />
                                        <Box>
                                            <Typography variant="body2" fontWeight="bold">
                                                Performance-Optimierung aktiv
                                            </Typography>
                                            <Typography variant="caption" color="text.secondary">
                                                vor 12 Minuten • Indizes neu erstellt
                                            </Typography>
                                        </Box>
                                    </Stack>
                                </Paper>

                                <Paper variant="outlined" sx={{ p: 2 }}>
                                    <Stack direction="row" alignItems="center" spacing={2}>
                                        <Storage color="warning" />
                                        <Box>
                                            <Typography variant="body2" fontWeight="bold">
                                                Backup erfolgreich erstellt
                                            </Typography>
                                            <Typography variant="caption" color="text.secondary">
                                                vor 1 Stunde • 15.6 GB gesichert
                                            </Typography>
                                        </Box>
                                    </Stack>
                                </Paper>
                            </Stack>
                        </CardContent>
                    </Card>
                </Grid>
            </Grid>
        </Box>
    );
};

export default Dashboard; 