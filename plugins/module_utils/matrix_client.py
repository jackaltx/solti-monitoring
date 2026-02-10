"""
Shared utilities for Matrix Client-Server API modules.
Provides wrapper for posting events and messages to Matrix rooms.
"""

from __future__ import absolute_import, division, print_function
__metaclass__ = type

import json
import time
import hashlib
from ansible.module_utils.urls import fetch_url
from ansible.module_utils.basic import AnsibleModule


class MatrixClientAPI:
    """
    Wrapper for Matrix Client-Server API calls.

    Used for posting events and messages to Matrix rooms.
    Unlike MatrixAdminAPI (solti-matrix-mgr), this uses the Client-Server API
    which is available to regular users and bots.

    API Reference: https://spec.matrix.org/v1.10/client-server-api/
    """

    CLIENT_API_BASE = "/_matrix/client/v3"

    def __init__(self, module, homeserver_url, access_token, validate_certs=True):
        """
        Initialize Matrix Client API wrapper.

        Args:
            module: AnsibleModule instance
            homeserver_url: Base URL of Matrix homeserver
            access_token: User/bot access token
            validate_certs: Whether to validate SSL certificates
        """
        self.module = module
        self.homeserver_url = homeserver_url.rstrip('/')
        self.access_token = access_token
        self.validate_certs = validate_certs

    def _request(self, method, endpoint, data=None):
        """
        Make an authenticated request to the Client-Server API.

        Args:
            method: HTTP method (GET, POST, PUT, DELETE)
            endpoint: API endpoint (without /v3 prefix)
            data: Optional dict to send as JSON body

        Returns:
            dict with status_code, body, url
        """
        url = f"{self.homeserver_url}{self.CLIENT_API_BASE}/{endpoint}"

        headers = {
            "Authorization": f"Bearer {self.access_token}",
            "Content-Type": "application/json",
        }

        body = json.dumps(data) if data else None

        response, info = fetch_url(
            self.module,
            url,
            method=method,
            headers=headers,
            data=body,
        )

        status_code = info.get('status', -1)

        if response:
            try:
                body = json.loads(response.read())
            except (ValueError, AttributeError):
                body = {}
        else:
            body = {}
            if 'body' in info:
                try:
                    body = json.loads(info['body'])
                except ValueError:
                    body = {'raw': info.get('body', '')}

        return {
            'status_code': status_code,
            'body': body,
            'url': url,
        }

    def get(self, endpoint):
        """GET request to Client-Server API."""
        return self._request("GET", endpoint)

    def post(self, endpoint, data=None):
        """POST request to Client-Server API."""
        return self._request("POST", endpoint, data=data)

    def put(self, endpoint, data=None):
        """PUT request to Client-Server API."""
        return self._request("PUT", endpoint, data=data)

    def send_event(self, room_id, event_type, content, transaction_id=None):
        """
        Send a custom event to a Matrix room.

        API: PUT /_matrix/client/v3/rooms/{room_id}/send/{event_type}/{txn_id}

        Args:
            room_id: Room ID (!xxx:server.com) or alias (#xxx:server.com)
            event_type: Event type (e.g., 'com.solti.verify.fail')
            content: Event content dict
            transaction_id: Optional transaction ID for idempotency

        Returns:
            dict with status_code, body (contains event_id on success)
        """
        # Resolve room alias to ID if needed
        if room_id.startswith('#'):
            resolved = self.resolve_room_alias(room_id)
            if resolved['status_code'] == 200:
                room_id = resolved['body'].get('room_id')
            else:
                return resolved

        # Generate transaction ID if not provided
        if not transaction_id:
            transaction_id = self._generate_transaction_id(room_id, event_type)

        endpoint = f"rooms/{room_id}/send/{event_type}/{transaction_id}"
        return self.put(endpoint, data=content)

    def send_message(self, room_id, msgtype, body, formatted_body=None):
        """
        Send a standard m.room.message event.

        Args:
            room_id: Room ID or alias
            msgtype: Message type (m.text, m.notice, etc.)
            body: Plain text message body
            formatted_body: Optional HTML formatted body

        Returns:
            dict with status_code, body (contains event_id on success)
        """
        content = {
            "msgtype": msgtype,
            "body": body,
        }

        if formatted_body:
            content["format"] = "org.matrix.custom.html"
            content["formatted_body"] = formatted_body

        return self.send_event(room_id, "m.room.message", content)

    def resolve_room_alias(self, room_alias):
        """
        Resolve a room alias to a room ID.

        API: GET /_matrix/client/v3/directory/room/{room_alias}

        Args:
            room_alias: Room alias (e.g., '#solti-verify:jackaltx.com')

        Returns:
            dict with status_code, body (contains room_id on success)
        """
        # URL encode the room alias
        import urllib.parse
        encoded_alias = urllib.parse.quote(room_alias, safe='')
        endpoint = f"directory/room/{encoded_alias}"
        return self.get(endpoint)

    def get_room_state(self, room_id):
        """
        Get all state events for a room.

        API: GET /_matrix/client/v3/rooms/{room_id}/state

        Args:
            room_id: Room ID

        Returns:
            dict with status_code, body (list of state events on success)
        """
        endpoint = f"rooms/{room_id}/state"
        return self.get(endpoint)

    def _generate_transaction_id(self, room_id, event_type):
        """
        Generate a unique transaction ID for event idempotency.

        Uses timestamp + room_id + event_type hash to ensure uniqueness
        while allowing retries to be idempotent.

        Args:
            room_id: Room ID
            event_type: Event type

        Returns:
            str: Transaction ID
        """
        timestamp = str(int(time.time()))
        unique_str = f"{timestamp}-{room_id}-{event_type}"
        hash_suffix = hashlib.md5(unique_str.encode()).hexdigest()[:8]
        return f"ansible-{timestamp}-{hash_suffix}"


# Helper functions for common operations

def resolve_room_identifier(api, room_identifier):
    """
    Resolve a room identifier (ID or alias) to a room ID.

    Args:
        api: MatrixClientAPI instance
        room_identifier: Room ID (!xxx) or alias (#xxx)

    Returns:
        str: Room ID, or None if resolution failed
    """
    if room_identifier.startswith('!'):
        # Already a room ID
        return room_identifier
    elif room_identifier.startswith('#'):
        # Resolve alias
        result = api.resolve_room_alias(room_identifier)
        if result['status_code'] == 200:
            return result['body'].get('room_id')
        else:
            return None
    else:
        # Invalid format
        return None


def post_verification_event(api, room_id, status, services, context=None):
    """
    Post a verification result event to a Matrix room.

    Args:
        api: MatrixClientAPI instance
        room_id: Room ID or alias
        status: 'PASSED' or 'FAILED'
        services: Dict of service verification results
        context: Optional dict of context information

    Returns:
        dict with status_code, body
    """
    event_type = "com.solti.verify.fail" if status == "FAILED" else "com.solti.verify.pass"

    content = {
        "status": status,
        "services": services,
        "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }

    if context:
        content["context"] = context

    return api.send_event(room_id, event_type, content)
