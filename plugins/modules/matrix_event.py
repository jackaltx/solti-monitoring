#!/usr/bin/python
# -*- coding: utf-8 -*-

"""
Ansible module for posting structured events to Matrix rooms.
"""

from __future__ import absolute_import, division, print_function
__metaclass__ = type

DOCUMENTATION = r'''
---
module: matrix_event
short_description: Post structured events to Matrix rooms via Client-Server API
version_added: "0.1.0"
description:
    - Post custom events to Matrix rooms using the Client-Server API
    - Accepts YAML dictionaries and converts them to JSON event content
    - Supports both room IDs (!xxx:server.com) and room aliases (#xxx:server.com)
    - Provides idempotency via transaction IDs
options:
    homeserver_url:
        description: URL of the Matrix homeserver
        required: true
        type: str
    access_token:
        description: Bot or user access token for authentication
        required: true
        type: str
        no_log: true
    room_id:
        description: Room ID (!xxx:server.com) or alias (#xxx:server.com)
        required: true
        type: str
    event_type:
        description: Custom event type (e.g., 'com.solti.verify.fail')
        required: true
        type: str
    event_content:
        description: Event content as YAML dict (will be converted to JSON)
        required: true
        type: dict
    state:
        description: Whether to post the event
        type: str
        choices: ['present', 'absent']
        default: present
    transaction_id:
        description: Optional explicit transaction ID for idempotency
        type: str
        required: false
    validate_certs:
        description: Validate SSL certificates
        type: bool
        default: true
author:
    - SOLTI Contributors
'''

EXAMPLES = r'''
- name: Post verification failure event
  jackaltx.solti_monitoring.matrix_event:
    homeserver_url: "https://matrix-web.jackaltx.com"
    access_token: "{{ bot_token }}"
    room_id: "#solti-verify:jackaltx.com"
    event_type: "com.solti.verify.fail"
    event_content:
      service: "jackaltx.solti_monitoring.loki"
      host: "monitor11.a0a0.org"
      test: "verify_loki_query_endpoint"
      error: "Connection timeout after 5s"
      severity: "error"
      context:
        playbook: "{{ playbook_dir }}"
        distribution: "debian12"

- name: Post verification success event
  jackaltx.solti_monitoring.matrix_event:
    homeserver_url: "https://matrix-web.jackaltx.com"
    access_token: "{{ bot_token }}"
    room_id: "!NGwlzxqbkdXnRGKvEF:jackaltx.com"
    event_type: "com.solti.verify.pass"
    event_content:
      status: "PASSED"
      services:
        loki: true
        influxdb: true
      timestamp: "{{ ansible_date_time.iso8601 }}"

- name: Post deployment started event
  jackaltx.solti_monitoring.matrix_event:
    homeserver_url: "https://matrix.jackaltx.com"
    access_token: "{{ bot_token }}"
    room_id: "#solti-deploy:jackaltx.com"
    event_type: "com.solti.deploy.start"
    event_content:
      service: "alloy"
      host: "fleur.lavnet.net"
      playbook: "fleur-alloy.yml"
'''

RETURN = r'''
event_id:
    description: Matrix event ID of the posted event
    returned: success
    type: str
    sample: "$abc123def456:jackaltx.com"
room_id:
    description: Room ID where event was posted
    returned: success
    type: str
    sample: "!NGwlzxqbkdXnRGKvEF:jackaltx.com"
transaction_id:
    description: Transaction ID used for the request
    returned: success
    type: str
    sample: "ansible-1707574800-abc12345"
event_type:
    description: Event type that was posted
    returned: success
    type: str
    sample: "com.solti.verify.fail"
'''

from ansible.module_utils.basic import AnsibleModule

# Import from collection's module_utils
try:
    from ansible_collections.jackaltx.solti_monitoring.plugins.module_utils.matrix_client import (
        MatrixClientAPI,
        resolve_room_identifier
    )
except ImportError:
    # Fallback for local development
    from ansible.module_utils.matrix_client import MatrixClientAPI, resolve_room_identifier


def main():
    """Main module execution."""
    module = AnsibleModule(
        argument_spec=dict(
            homeserver_url=dict(type='str', required=True),
            access_token=dict(type='str', required=True, no_log=True),
            room_id=dict(type='str', required=True),
            event_type=dict(type='str', required=True),
            event_content=dict(type='dict', required=True),
            state=dict(type='str', default='present', choices=['present', 'absent']),
            transaction_id=dict(type='str', required=False),
            validate_certs=dict(type='bool', default=True),
        ),
        supports_check_mode=True,
    )

    # Extract parameters
    homeserver_url = module.params['homeserver_url']
    access_token = module.params['access_token']
    room_id = module.params['room_id']
    event_type = module.params['event_type']
    event_content = module.params['event_content']
    state = module.params['state']
    transaction_id = module.params.get('transaction_id')
    validate_certs = module.params['validate_certs']

    # Skip if state is absent
    if state == 'absent':
        module.exit_json(changed=False, skipped=True, msg="State is absent, skipping event post")

    # Skip in check mode
    if module.check_mode:
        module.exit_json(changed=True, skipped=True, msg="Check mode, would post event")

    # Initialize API client
    try:
        api = MatrixClientAPI(module, homeserver_url, access_token, validate_certs)
    except Exception as e:
        module.fail_json(msg=f"Failed to initialize Matrix API client: {str(e)}")

    # Resolve room alias to ID if needed
    resolved_room_id = resolve_room_identifier(api, room_id)
    if not resolved_room_id:
        module.fail_json(
            msg=f"Failed to resolve room identifier: {room_id}",
            room_id=room_id
        )

    # Post event to Matrix
    try:
        result = api.send_event(
            room_id=resolved_room_id,
            event_type=event_type,
            content=event_content,
            transaction_id=transaction_id
        )

        if result['status_code'] == 200:
            module.exit_json(
                changed=True,
                event_id=result['body'].get('event_id'),
                room_id=resolved_room_id,
                transaction_id=transaction_id or api._generate_transaction_id(resolved_room_id, event_type),
                event_type=event_type,
                msg="Event posted successfully"
            )
        else:
            module.fail_json(
                msg=f"Failed to post event: HTTP {result['status_code']}",
                status_code=result['status_code'],
                body=result['body'],
                url=result['url']
            )

    except Exception as e:
        module.fail_json(msg=f"Exception posting event: {str(e)}")


if __name__ == '__main__':
    main()
