#!/usr/bin/env python3
"""
Webhook receiver for GitHub/GitLab events to trigger Jenkins pipeline
"""

from flask import Flask, request, jsonify
from datetime import datetime
import os
import requests
import hmac
import hashlib
import json

app = Flask(__name__)

# Configuration
JENKINS_URL = os.getenv('JENKINS_URL', 'http://localhost:8080')
JENKINS_JOB = os.getenv('JENKINS_JOB', 'medicine-stock-pipeline')
JENKINS_TOKEN = os.getenv('JENKINS_TOKEN', 'your-jenkins-token')
WEBHOOK_SECRET = os.getenv('WEBHOOK_SECRET', 'your-webhook-secret')

def verify_github_signature(request_body, signature):
    """Verify GitHub webhook signature"""
    if not WEBHOOK_SECRET:
        return True
    
    hash_object = hmac.new(
        WEBHOOK_SECRET.encode(),
        msg=request_body,
        digestmod=hashlib.sha256
    )
    expected_signature = "sha256=" + hash_object.hexdigest()
    return hmac.compare_digest(expected_signature, signature)

def trigger_jenkins_build(branch, commit_sha=None):
    """Trigger Jenkins build"""
    try:
        jenkins_build_url = f"{JENKINS_URL}/job/{JENKINS_JOB}/buildWithParameters"
        
        params = {
            'BRANCH': branch,
            'COMMIT_SHA': commit_sha or 'latest',
            'IMAGE_TAG': f"{branch}-{datetime.now().strftime('%Y%m%d%H%M%S')}"
        }
        
        response = requests.post(
            jenkins_build_url,
            auth=(os.getenv('JENKINS_USER', 'admin'), JENKINS_TOKEN),
            params=params,
            timeout=10
        )
        
        return response.status_code in [200, 201]
    except Exception as e:
        print(f"Jenkins trigger error: {e}")
        return False

@app.route('/github-webhook', methods=['POST'])
def github_webhook():
    """GitHub webhook endpoint"""
    try:
        # Verify signature
        signature = request.headers.get('X-Hub-Signature-256', '')
        if not verify_github_signature(request.data, signature):
            return jsonify({'error': 'Invalid signature'}), 401
        
        payload = request.get_json()
        
        # Extract event type and branch
        event_type = request.headers.get('X-GitHub-Event', '')
        
        if event_type == 'push':
            branch = payload['ref'].split('/')[-1]
            commit_sha = payload['after']
            
            print(f"[{datetime.now()}] GitHub push event on branch: {branch}")
            
            # Trigger Jenkins build for main/master branches
            if branch in ['main', 'master', 'develop']:
                if trigger_jenkins_build(branch, commit_sha):
                    return jsonify({
                        'status': 'success',
                        'message': f'Build triggered for {branch}',
                        'commit': commit_sha
                    }), 200
                else:
                    return jsonify({'error': 'Failed to trigger Jenkins'}), 500
        
        elif event_type == 'pull_request':
            pr_number = payload['pull_request']['number']
            branch = payload['pull_request']['head']['ref']
            
            print(f"[{datetime.now()}] GitHub PR #{pr_number} on branch: {branch}")
            
            # Trigger Jenkins build for PRs
            if trigger_jenkins_build(f"pr-{pr_number}", payload['pull_request']['head']['sha']):
                return jsonify({
                    'status': 'success',
                    'message': f'Build triggered for PR #{pr_number}',
                }), 200
        
        return jsonify({'status': 'ignored', 'event': event_type}), 200
        
    except Exception as e:
        print(f"Webhook error: {e}")
        return jsonify({'error': str(e)}), 400

@app.route('/gitlab-webhook', methods=['POST'])
def gitlab_webhook():
    """GitLab webhook endpoint"""
    try:
        token = request.headers.get('X-Gitlab-Token', '')
        if token != WEBHOOK_SECRET:
            return jsonify({'error': 'Invalid token'}), 401
        
        payload = request.get_json()
        event_type = request.headers.get('X-Gitlab-Event', '')
        
        if event_type == 'Push Hook':
            branch = payload['ref'].split('/')[-1]
            commit_sha = payload['checkout_sha']
            
            print(f"[{datetime.now()}] GitLab push event on branch: {branch}")
            
            if branch in ['main', 'master', 'develop']:
                if trigger_jenkins_build(branch, commit_sha):
                    return jsonify({
                        'status': 'success',
                        'message': f'Build triggered for {branch}',
                    }), 200
        
        elif event_type == 'Merge Request Hook':
            mr_iid = payload['object_attributes']['iid']
            branch = payload['object_attributes']['source_branch']
            
            print(f"[{datetime.now()}] GitLab MR !{mr_iid} on branch: {branch}")
            
            if trigger_jenkins_build(f"mr-{mr_iid}", payload['object_attributes']['last_commit']['id']):
                return jsonify({
                    'status': 'success',
                    'message': f'Build triggered for MR !{mr_iid}',
                }), 200
        
        return jsonify({'status': 'ignored', 'event': event_type}), 200
        
    except Exception as e:
        print(f"GitLab webhook error: {e}")
        return jsonify({'error': str(e)}), 400

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now().isoformat(),
        'jenkins_url': JENKINS_URL,
        'job': JENKINS_JOB
    }), 200

@app.route('/', methods=['GET'])
def index():
    """Root endpoint"""
    return jsonify({
        'name': 'Medicine Stock CI/CD Webhook Receiver',
        'endpoints': {
            '/github-webhook': 'GitHub webhook receiver',
            '/gitlab-webhook': 'GitLab webhook receiver',
            '/health': 'Health check'
        }
    }), 200

if __name__ == '__main__':
    port = int(os.getenv('WEBHOOK_PORT', 5555))
    debug = os.getenv('DEBUG', 'false').lower() == 'true'
    
    print(f"[{datetime.now()}] Starting webhook receiver...")
    print(f"Jenkins URL: {JENKINS_URL}")
    print(f"Jenkins Job: {JENKINS_JOB}")
    print(f"Listening on port {port}")
    
    app.run(host='0.0.0.0', port=port, debug=debug)
