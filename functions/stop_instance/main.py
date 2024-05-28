import google.auth
from googleapiclient.discovery import build
from datetime import datetime, timedelta
import os

PROJECT_ID = os.environ['PROJECT_ID']
INSTANCE_ZONE = os.environ['INSTANCE_ZONE']
INSTANCE_NAME = os.environ['INSTANCE_NAME']
METRIC_NAME = os.environ['METRIC_NAME']

def check_instance_activity(request):
    credentials, project = google.auth.default()
    monitoring_client = build('monitoring', 'v3', credentials=credentials)
    compute_client = build('compute', 'v1', credentials=credentials)
    
    now = datetime.utcnow()
    start_time = (now - timedelta(minutes=2)).isoformat("T") + "Z"
    
    filter_str = f'metric.type="logging.googleapis.com/user/{METRIC_NAME}" AND resource.labels.instance_id="{INSTANCE_NAME}" AND timestamp >= "{start_time}"'
    
    time_series_list = monitoring_client.projects().timeSeries().list(
        name=f'projects/{PROJECT_ID}',
        filter=filter_str,
        interval_startTime=start_time,
        interval_endTime=now.isoformat("T") + "Z",
    ).execute().get('timeSeries', [])
    
    if not time_series_list:
        stop_instance(compute_client)
    
    return 'Checked instance activity', 200

def stop_instance(compute_client):
    request = compute_client.instances().stop(
        project=PROJECT_ID,
        zone=INSTANCE_ZONE,
        instance=INSTANCE_NAME
    )
    response = request.execute()
    return response
