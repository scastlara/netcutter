export DOCKER_OPTS="--dns 208.67.222.222 --dns 208.67.220.220"
export THYIPADDR=0.0.0.0
export THYNEO4J_AUTH='neo4j/1234'
rm -v $NEOWD/data/dbms/{auth,auth.ini} 2> /dev/null
docker run \
       --detach \
       --publish=${THYIPADDR}:7474:7474 \
       --publish=${THYIPADDR}:7473:7473 \
       --publish=${THYIPADDR}:7687:7687 \
       --env=NEO4J_dbms_memory_heap_initial__size=2G \
       --env=NEO4J_dbms_memory_heap_max__size=2G \
       --env=NEO4J_dbms_memory_pagecache_size=2G  \
       --env=NEO4J_dbms_allow__upgrade=true \
       --env=NEO4J_dbms_connectors_default__advertised__address=${THYIPADDR} \
       --env=NEO4J_dbms_connector_bolt_enabled=true \
       --env=NEO4J_dbms_connector_http_enabled=true \
       --env=NEO4J_dbms_connector_https_enabled=true \
       --env=NEO4J_AUTH=${THYNEO4J_AUTH} \
       --volume=$NEOWD/data:/var/lib/neo4j/data:rw \
       --volume=$NEOWD/logs:/var/lib/neo4j/logs:rw \
       --volume=$NEOWD/conf:/var/lib/neo4j/conf:rw \
       --volume=$NEOWD/import:/var/lib/neo4j/import:rw \
       netcutter-neo4j > /dev/null 2> /dev/null;
