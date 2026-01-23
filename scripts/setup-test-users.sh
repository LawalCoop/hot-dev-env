#!/bin/bash
# Setup test users for Hanko SSO testing
# Overwrites email/osm_id of specific users with test team credentials
#
# Usage: ./scripts/setup-test-users.sh [app]
#   app: dronetm, fair, umap, or all (default)

set -e

# Test team credentials
HERNAN_EMAIL="hernangigena@gmail.com"
HERNAN_OSM_ID="23393526"

JUSTINA_EMAIL="justina@animus.com.ar"
JUSTINA_OSM_ID="12759992"

ANDREA_EMAIL="andreatchirillano@hotmail.com"
ANDREA_OSM_ID="23470445"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

setup_dronetm() {
    echo -e "${YELLOW}Setting up drone-tm...${NC}"

    # Pisar emails de usuarios específicos
    # Philip Hippolyte (58 proj) → Hernan
    # Juan Melo (28 proj) → Justina
    # Ivan Gayton (27 proj) → Andrea
    # Primero limpiamos los emails target si ya existen en otros users, luego asignamos
    docker exec hotosm-dronetm-db psql -U dtm -d dtm_db -c "
    UPDATE users SET email_address = 'old_' || id || '@test.local' WHERE email_address LIKE 'old_%';
    UPDATE users SET email_address = 'old_' || email_address WHERE email_address IN ('$HERNAN_EMAIL', '$JUSTINA_EMAIL', '$ANDREA_EMAIL');
    UPDATE users SET email_address = '$HERNAN_EMAIL' WHERE email_address = 'philip.hippolyte@hotosm.org';
    UPDATE users SET email_address = '$JUSTINA_EMAIL' WHERE email_address = 'juan.melo@hotosm.org';
    UPDATE users SET email_address = '$ANDREA_EMAIL' WHERE email_address = 'ivan.gayton@hotosm.org';
    "

    echo -e "${GREEN}drone-tm users:${NC}"
    docker exec hotosm-dronetm-db psql -U dtm -d dtm_db -t -c "
    SELECT email_address, name, (SELECT COUNT(*) FROM projects WHERE author_id = users.id) as projects
    FROM users WHERE email_address IN ('$HERNAN_EMAIL', '$JUSTINA_EMAIL', '$ANDREA_EMAIL')
    ORDER BY projects DESC;"
}

setup_fair() {
    echo -e "${YELLOW}Setting up fAIr...${NC}"

    # Pisar osm_id de usuarios específicos
    # OmranNAJJAR (osm_id 12094445, 177 trainings) → Hernan
    # krschap (osm_id 7004124, 72 trainings) → Justina
    # stampachradim (osm_id 3245168, 20 trainings) → Andrea

    # Primero limpiar osm_ids viejos (>900M) y target si ya existen
    docker exec hotosm-fair-db psql -U fair -d fair -c "
    DELETE FROM core_training WHERE user_id > 900000000 OR user_id IN ($HERNAN_OSM_ID, $JUSTINA_OSM_ID, $ANDREA_OSM_ID);
    DELETE FROM core_model WHERE user_id > 900000000 OR user_id IN ($HERNAN_OSM_ID, $JUSTINA_OSM_ID, $ANDREA_OSM_ID);
    DELETE FROM core_aoi WHERE user_id > 900000000 OR user_id IN ($HERNAN_OSM_ID, $JUSTINA_OSM_ID, $ANDREA_OSM_ID);
    DELETE FROM core_dataset WHERE user_id > 900000000 OR user_id IN ($HERNAN_OSM_ID, $JUSTINA_OSM_ID, $ANDREA_OSM_ID);
    DELETE FROM core_feedback WHERE user_id > 900000000 OR user_id IN ($HERNAN_OSM_ID, $JUSTINA_OSM_ID, $ANDREA_OSM_ID);
    DELETE FROM core_prediction WHERE user_id > 900000000 OR user_id IN ($HERNAN_OSM_ID, $JUSTINA_OSM_ID, $ANDREA_OSM_ID);
    DELETE FROM core_usernotification WHERE user_id > 900000000 OR user_id IN ($HERNAN_OSM_ID, $JUSTINA_OSM_ID, $ANDREA_OSM_ID);
    DELETE FROM auth_user WHERE osm_id > 900000000 OR osm_id IN ($HERNAN_OSM_ID, $JUSTINA_OSM_ID, $ANDREA_OSM_ID);
    "

    docker exec hotosm-fair-db psql -U fair -d fair -c "
    -- Hernan: 12094445 → 23393526
    UPDATE core_training SET user_id = $HERNAN_OSM_ID WHERE user_id = 12094445;
    UPDATE core_model SET user_id = $HERNAN_OSM_ID WHERE user_id = 12094445;
    UPDATE core_aoi SET user_id = $HERNAN_OSM_ID WHERE user_id = 12094445;
    UPDATE core_dataset SET user_id = $HERNAN_OSM_ID WHERE user_id = 12094445;
    UPDATE core_feedback SET user_id = $HERNAN_OSM_ID WHERE user_id = 12094445;
    UPDATE core_prediction SET user_id = $HERNAN_OSM_ID WHERE user_id = 12094445;
    UPDATE core_usernotification SET user_id = $HERNAN_OSM_ID WHERE user_id = 12094445;
    UPDATE auth_user SET osm_id = $HERNAN_OSM_ID WHERE osm_id = 12094445;

    -- Justina: 7004124 → 12759992
    UPDATE core_training SET user_id = $JUSTINA_OSM_ID WHERE user_id = 7004124;
    UPDATE core_model SET user_id = $JUSTINA_OSM_ID WHERE user_id = 7004124;
    UPDATE core_aoi SET user_id = $JUSTINA_OSM_ID WHERE user_id = 7004124;
    UPDATE core_dataset SET user_id = $JUSTINA_OSM_ID WHERE user_id = 7004124;
    UPDATE core_feedback SET user_id = $JUSTINA_OSM_ID WHERE user_id = 7004124;
    UPDATE core_prediction SET user_id = $JUSTINA_OSM_ID WHERE user_id = 7004124;
    UPDATE core_usernotification SET user_id = $JUSTINA_OSM_ID WHERE user_id = 7004124;
    UPDATE auth_user SET osm_id = $JUSTINA_OSM_ID WHERE osm_id = 7004124;

    -- Andrea: 3245168 → 23470445
    UPDATE core_training SET user_id = $ANDREA_OSM_ID WHERE user_id = 3245168;
    UPDATE core_model SET user_id = $ANDREA_OSM_ID WHERE user_id = 3245168;
    UPDATE core_aoi SET user_id = $ANDREA_OSM_ID WHERE user_id = 3245168;
    UPDATE core_dataset SET user_id = $ANDREA_OSM_ID WHERE user_id = 3245168;
    UPDATE core_feedback SET user_id = $ANDREA_OSM_ID WHERE user_id = 3245168;
    UPDATE core_prediction SET user_id = $ANDREA_OSM_ID WHERE user_id = 3245168;
    UPDATE core_usernotification SET user_id = $ANDREA_OSM_ID WHERE user_id = 3245168;
    UPDATE auth_user SET osm_id = $ANDREA_OSM_ID WHERE osm_id = 3245168;
    "

    echo -e "${GREEN}fAIr users:${NC}"
    docker exec hotosm-fair-db psql -U fair -d fair -t -c "
    SELECT osm_id, username, (SELECT COUNT(*) FROM core_training WHERE user_id = auth_user.osm_id) as trainings
    FROM auth_user WHERE osm_id IN ($HERNAN_OSM_ID, $JUSTINA_OSM_ID, $ANDREA_OSM_ID)
    ORDER BY trainings DESC;"
}

setup_umap() {
    echo -e "${YELLOW}Setting up uMap...${NC}"

    # Pisar osm_id en social_auth de usuarios específicos
    # mapeadora (id 78, 34 maps) → Hernan
    # netasciudadanas (id 108, 43 maps) → Justina
    # CartografiasVitales (id 67, 39 maps) → Andrea
    docker exec hotosm-umap-db psql -U umap -d umap -c "
    -- Primero limpiar uids target si ya existen (moverlos a valor temporal)
    UPDATE social_auth_usersocialauth SET uid = 'old_' || uid
    WHERE provider = 'openstreetmap-oauth2' AND uid IN ('$HERNAN_OSM_ID', '$JUSTINA_OSM_ID', '$ANDREA_OSM_ID');

    -- Hernan: user_id 78 (mapeadora)
    INSERT INTO social_auth_usersocialauth (user_id, provider, uid, extra_data, created, modified)
    VALUES (78, 'openstreetmap-oauth2', '$HERNAN_OSM_ID', '{}', NOW(), NOW())
    ON CONFLICT (provider, uid) DO UPDATE SET user_id = 78;

    -- Justina: user_id 108
    UPDATE social_auth_usersocialauth SET uid = '$JUSTINA_OSM_ID' WHERE user_id = 108;

    -- Andrea: user_id 67
    UPDATE social_auth_usersocialauth SET uid = '$ANDREA_OSM_ID' WHERE user_id = 67;
    "

    echo -e "${GREEN}uMap users:${NC}"
    docker exec hotosm-umap-db psql -U umap -d umap -t -c "
    SELECT s.uid as osm_id, u.username, (SELECT COUNT(*) FROM umap_map WHERE owner_id = u.id) as maps
    FROM auth_user u JOIN social_auth_usersocialauth s ON s.user_id = u.id
    WHERE s.uid IN ('$HERNAN_OSM_ID', '$JUSTINA_OSM_ID', '$ANDREA_OSM_ID')
    ORDER BY maps DESC;"
}

# Main
APP=${1:-all}

echo "============================================"
echo "Setting up test users for Hanko SSO testing"
echo "============================================"
echo ""
echo "Team credentials:"
echo "  Hernan:  $HERNAN_EMAIL / osm_id $HERNAN_OSM_ID"
echo "  Justina: $JUSTINA_EMAIL / osm_id $JUSTINA_OSM_ID"
echo "  Andrea:  $ANDREA_EMAIL / osm_id $ANDREA_OSM_ID"
echo ""

case $APP in
    dronetm)
        setup_dronetm
        ;;
    fair)
        setup_fair
        ;;
    umap)
        setup_umap
        ;;
    all)
        setup_dronetm
        echo ""
        setup_fair
        echo ""
        setup_umap
        ;;
    *)
        echo "Usage: $0 [dronetm|fair|umap|all]"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}Done!${NC}"
