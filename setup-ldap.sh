#!/usr/bin/env bash

if [[ "${ldap_container_name}" == "" ]]; then
    ldap_container_name="orz-ldap"
fi

if [[ "${docker_network}" == "" ]]; then
    docker_network="orz"
fi

script_path="$(
    cd -- "$(dirname "$0")" >/dev/null 2>&1
    pwd -P
)"

echo -n "Waiting for existing LDAP docker container to shut down..."
i=0
until ! docker ps | grep " ${ldap_container_name}$" >/dev/null 2>&1; do
    i=$((i + 1))
    docker stop "${ldap_container_name}" >/dev/null 2>&1
    echo -n "."
    sleep .1
    if [[ $i -gt 300 ]]; then
        echo "docker ps looking for ${ldap_container_name} timed out after 30 seconds"
        exit 1
    fi
done

echo
sleep 1
result=$(docker network create "${docker_network}" 2>&1)
if [[ $? -ne 0 ]]; then
    if [[ $result != "Error response from daemon: network with name ${docker_network} already exists" ]]; then
        echo "Creating docker network failed: [${result}]"
    fi
fi

# Force remove just incase the --rm didn't work on stop
docker rm -f "${ldap_container_name}" >/dev/null 2>&1

docker run \
    --name "${ldap_container_name}" \
    --network "${docker_network}" \
    --env LDAP_ORGANISATION="example" \
    --env LDAP_DOMAIN="example.org" \
    --env LDAP_ADMIN_PASSWORD="admin" \
    -p 389:389 \
    -p 636:636 \
    --detach \
    --rm \
    osixia/openldap:1.4.0

# ldapsearch -H ldap://localhost:389 -D cn=admin,dc=example,dc=org -x -w admin -b dc=example,dc=org -LLL
# ldapsearch -x -b "ou=vault-role-groups,dc=example,dc=org" -H ldap://localhost:389 -D cn=admin,dc=example,dc=org -x -w admin -LLL

# local test
#ldapsearch -H ldap://localhost -D cn=admin,dc=example,dc=org -x -w admin -b "ou=groups,dc=example,dc=org" -LLL "(|(memberUid=user1)(member=uid=user1,ou=users,dc=example,dc=org)(uniqueMember=uid=user1,ou=users,dc=example,dc=org))"

# TEST USER AUTH:
# ldapsearch -H ldap://localhost:389 -D uid=user1,ou=users,dc=example,dc=org -w password1 -x -b 'dc=example,dc=org' -LLL

echo -n "Waiting for LDAP to be healthy.."
i=0
while true; do
    i=$((i + 1))
    result=$(ldapsearch -H ldap://localhost:389 -D cn=admin,dc=example,dc=org -x -w admin -b dc=example,dc=org -LLL 2>/dev/null)
    if [[ $? -eq 0 ]]; then
        echo "OK!"
        break
    fi
    echo -n "."
    sleep .5
    if [[ $i -gt 20 ]]; then
        echo "LDAP health check startup timed out after 10 seconds"
        exit 1
    fi

done

# Mapping this into "/container/service/slapd/assets/config/bootstrap/ldif/custom/" doesn't work because you have to actually copy it in so it can chown/delete it when done.

# it's easier to let it setup all the default and clean out what we don't need.
#ldapdelete -D "cn=admin,dc=example,dc=org" -w admin "cn=user01,ou=users,dc=example,dc=org"
#ldapdelete -D "cn=admin,dc=example,dc=org" -w admin "cn=user02,ou=users,dc=example,dc=org"
#ldapdelete -D "cn=admin,dc=example,dc=org" -w admin "cn=readers,ou=users,dc=example,dc=org"

#ldapadd -x -D "cn=admin,dc=example,dc=org" -w admin -f ${script_path}/ldap_init.ldif

echo "==== REGULAR ADMIN ===="
ldapadd -x -D "cn=admin,dc=example,dc=org" -w admin -f ${script_path}/ldap_init.ldif

#echo "==== CONFIG ADMIN ===="
#ldapadd -x -D "cn=admin,cn=config" -w config -f ${script_path}/ldap_init_config_admin.ldif

exit 0

#cn=admin,dc=example,dc=org -x -w admin
#ldapmodify -h localhost -p 389 -D cn=admin,dc=example,dc=org -w admin -
#dn: uid=t_1682711066,ou=vault-dynamic-users,dc=example,dc=org
#changetype: delete
