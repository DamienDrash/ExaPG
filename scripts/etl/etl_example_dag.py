"""
ExaPG ETL Framework - Beispiel Airflow DAG
Dieses DAG zeigt, wie ETL-Jobs mit Airflow orchestriert werden können.
"""

from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python_operator import PythonOperator
from airflow.providers.postgres.operators.postgres import PostgresOperator
from airflow.providers.postgres.hooks.postgres import PostgresHook

# Standard-Argumente für alle Tasks in diesem DAG
default_args = {
    'owner': 'exapg',
    'depends_on_past': False,
    'start_date': datetime(2023, 1, 1),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

# Hilfsfunktion zum Auslesen der ETL-Job-Ergebnisse
def check_etl_job_results(job_id, **kwargs):
    pg_hook = PostgresHook(postgres_conn_id='postgres_default')
    
    # Hole das Ergebnis des letzten Runs für diesen Job
    sql_query = f"""
    SELECT 
        status, 
        rows_processed, 
        rows_loaded,
        rows_rejected,
        EXTRACT(EPOCH FROM (end_time - start_time)) as duration_seconds,
        error_message
    FROM 
        etl_framework.etl_job_runs
    WHERE 
        job_id = {job_id}
    ORDER BY 
        run_id DESC
    LIMIT 1
    """
    
    result = pg_hook.get_first(sql_query)
    
    if not result:
        raise ValueError(f"Keine Ergebnisse für ETL-Job {job_id} gefunden!")
    
    status, rows_processed, rows_loaded, rows_rejected, duration, error_message = result
    
    if status != 'SUCCESS':
        raise Exception(f"ETL-Job {job_id} fehlgeschlagen: {error_message}")
    
    # Schreibe Informationen in die Task-Logs
    print(f"ETL-Job {job_id} erfolgreich ausgeführt:")
    print(f"Verarbeitete Zeilen: {rows_processed}")
    print(f"Geladene Zeilen: {rows_loaded}")
    print(f"Abgelehnte Zeilen: {rows_rejected}")
    print(f"Dauer: {duration:.2f} Sekunden")
    
    # Gebe das Ergebnis an XCom weiter
    return {
        'job_id': job_id,
        'status': status,
        'rows_processed': rows_processed,
        'rows_loaded': rows_loaded,
        'rows_rejected': rows_rejected,
        'duration_seconds': duration
    }

# Funktion zum Ausführen von Datenqualitätsprüfungen
def check_data_quality(job_id, **kwargs):
    pg_hook = PostgresHook(postgres_conn_id='postgres_default')
    
    # Hole das Ergebnis der Datenqualitätsprüfungen
    sql_query = f"""
    SELECT 
        r.run_id,
        COUNT(q.result_id) as total_checks,
        SUM(CASE WHEN q.passed THEN 1 ELSE 0 END) as passed_checks,
        SUM(CASE WHEN NOT q.passed THEN 1 ELSE 0 END) as failed_checks,
        jsonb_agg(jsonb_build_object(
            'check_id', c.check_id,
            'check_name', c.check_name,
            'passed', q.passed,
            'error_message', q.error_message
        )) as check_details
    FROM 
        etl_framework.etl_job_runs r
        JOIN etl_framework.data_quality_results q ON r.run_id = q.run_id
        JOIN etl_framework.data_quality_checks c ON q.check_id = c.check_id
    WHERE 
        r.job_id = {job_id}
    GROUP BY 
        r.run_id
    ORDER BY 
        r.run_id DESC
    LIMIT 1
    """
    
    result = pg_hook.get_first(sql_query)
    
    if not result:
        print(f"Keine Datenqualitätsprüfungen für ETL-Job {job_id} gefunden.")
        return None
    
    run_id, total_checks, passed_checks, failed_checks, check_details = result
    
    print(f"Datenqualitätsergebnisse für Job {job_id}, Run {run_id}:")
    print(f"Gesamte Prüfungen: {total_checks}")
    print(f"Bestandene Prüfungen: {passed_checks}")
    print(f"Fehlgeschlagene Prüfungen: {failed_checks}")
    
    if failed_checks > 0:
        print("Fehlgeschlagene Prüfungen:")
        for check in check_details:
            if not check.get('passed'):
                print(f"- {check.get('check_name')}: {check.get('error_message')}")
                
        # Je nach Konfiguration könnte der DAG hier abgebrochen werden
        # Für dieses Beispiel geben wir nur eine Warnung aus
        print("WARNUNG: Es gibt fehlgeschlagene Datenqualitätsprüfungen!")
    
    return {
        'run_id': run_id,
        'total_checks': total_checks,
        'passed_checks': passed_checks,
        'failed_checks': failed_checks,
        'quality_score': passed_checks / total_checks if total_checks > 0 else None
    }

# Erstelle den DAG
with DAG(
    'exapg_etl_pipeline',
    default_args=default_args,
    description='ExaPG ETL Pipeline für Kundendaten und Bestellungen',
    schedule_interval=timedelta(days=1),
    catchup=False
) as dag:
    
    # Task 1: Führe den Kunden-ETL-Job aus
    run_customer_etl = PostgresOperator(
        task_id='run_customer_etl',
        postgres_conn_id='postgres_default',
        sql="""
        SELECT etl_framework.run_etl_job(
            (SELECT job_id FROM etl_framework.etl_jobs WHERE job_name = 'customer_data_etl'),
            FALSE
        );
        """,
        autocommit=True
    )
    
    # Task 2: Prüfe das Ergebnis des Kunden-ETL-Jobs
    check_customer_etl = PythonOperator(
        task_id='check_customer_etl',
        python_callable=check_etl_job_results,
        op_kwargs={'job_id': "{{ ti.xcom_pull(task_ids='run_customer_etl')['job_id'] }}"},
        provide_context=True
    )
    
    # Task 3: Prüfe die Datenqualität des Kunden-ETL-Jobs
    check_customer_quality = PythonOperator(
        task_id='check_customer_quality',
        python_callable=check_data_quality,
        op_kwargs={'job_id': "{{ ti.xcom_pull(task_ids='run_customer_etl')['job_id'] }}"},
        provide_context=True
    )
    
    # Task 4: Führe den Bestellungen-ETL-Job aus
    run_orders_etl = PostgresOperator(
        task_id='run_orders_etl',
        postgres_conn_id='postgres_default',
        sql="""
        SELECT etl_framework.run_etl_job(
            (SELECT job_id FROM etl_framework.etl_jobs WHERE job_name = 'orders_data_etl'),
            FALSE
        );
        """,
        autocommit=True
    )
    
    # Task 5: Prüfe das Ergebnis des Bestellungen-ETL-Jobs
    check_orders_etl = PythonOperator(
        task_id='check_orders_etl',
        python_callable=check_etl_job_results,
        op_kwargs={'job_id': "{{ ti.xcom_pull(task_ids='run_orders_etl')['job_id'] }}"},
        provide_context=True
    )
    
    # Task 6: Prüfe die Datenqualität des Bestellungen-ETL-Jobs
    check_orders_quality = PythonOperator(
        task_id='check_orders_quality',
        python_callable=check_data_quality,
        op_kwargs={'job_id': "{{ ti.xcom_pull(task_ids='run_orders_etl')['job_id'] }}"},
        provide_context=True
    )
    
    # Task 7: Führe den Bestellpositionen-ETL-Job aus
    run_order_items_etl = PostgresOperator(
        task_id='run_order_items_etl',
        postgres_conn_id='postgres_default',
        sql="""
        SELECT etl_framework.run_etl_job(
            (SELECT job_id FROM etl_framework.etl_jobs WHERE job_name = 'order_items_data_etl'),
            FALSE
        );
        """,
        autocommit=True
    )
    
    # Task 8: Prüfe das Ergebnis des Bestellpositionen-ETL-Jobs
    check_order_items_etl = PythonOperator(
        task_id='check_order_items_etl',
        python_callable=check_etl_job_results,
        op_kwargs={'job_id': "{{ ti.xcom_pull(task_ids='run_order_items_etl')['job_id'] }}"},
        provide_context=True
    )
    
    # Task 9: Prüfe die Datenqualität des Bestellpositionen-ETL-Jobs
    check_order_items_quality = PythonOperator(
        task_id='check_order_items_quality',
        python_callable=check_data_quality,
        op_kwargs={'job_id': "{{ ti.xcom_pull(task_ids='run_order_items_etl')['job_id'] }}"},
        provide_context=True
    )
    
    # Definiere die Task-Abhängigkeiten
    run_customer_etl >> check_customer_etl >> check_customer_quality >> run_orders_etl
    run_orders_etl >> check_orders_etl >> check_orders_quality >> run_order_items_etl
    run_order_items_etl >> check_order_items_etl >> check_order_items_quality 