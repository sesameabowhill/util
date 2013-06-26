#!/bin/sh
for i in migration-current-activity migration-current-activity-small-tasks migration-event migration-current-activity-archive migration-current-activity-verify-ui-tasks migration-workflow ; do service $i stop; service $i start; done
