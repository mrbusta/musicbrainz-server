#!/bin/bash

set -o errexit
cd `dirname $0`

eval `./admin/ShowDBDefs`

echo `date` : Upgrading to N.G.S.!!1!

echo 'DROP SCHEMA musicbrainz CASCADE;' | ./admin/psql READWRITE
echo 'DROP SCHEMA musicbrainz CASCADE;' | ./admin/psql RAWDATA
echo 'CREATE SCHEMA musicbrainz;' | ./admin/psql READWRITE
echo 'CREATE SCHEMA musicbrainz;' | ./admin/psql RAWDATA

echo `date` : Installing cube extension
./admin/InitDb.pl --install-extension=cube.sql --extension-schema=musicbrainz

echo `date` : Creating schema
./admin/psql READWRITE <./admin/sql/CreateTables.sql
./admin/psql READWRITE <./admin/sql/CreateFunctions.sql
./admin/psql --system READWRITE <./admin/sql/CreateSearchConfiguration.sql
./admin/psql RAWDATA <./admin/sql/vertical/rawdata/CreateTables.sql

echo `date` : Migrating data
./admin/psql READWRITE <./admin/sql/updates/ngs-artist.sql
./admin/sql/updates/ngs-artistcredit.pl
./admin/psql READWRITE <./admin/sql/updates/ngs.sql
./admin/sql/updates/ngs-ars.pl
./admin/sql/updates/ngs-rawdata.pl
./admin/sql/updates/ngs-artistcredit-2.pl

echo `date` : Merging releases
./admin/sql/updates/ngs-merge-releases.pl
echo `date` : Merging recordings
./admin/sql/updates/ngs-merge-recordings.pl
echo `date` : Create tracklist index
./admin/psql READWRITE < ./admin/sql/updates/ngs-cdlookup.sql

echo `date` : Fixing refcounts
./admin/psql READWRITE <./admin/sql/updates/ngs-refcount.sql

echo `date` : Creating primary keys
./admin/psql READWRITE <./admin/sql/CreatePrimaryKeys.sql
./admin/psql RAWDATA <./admin/sql/vertical/rawdata/CreatePrimaryKeys.sql

echo `date` : Collecting cover art URLs
./admin/RebuildCoverArtUrls.pl

if [ "$REPLICATION_TYPE" != "$RT_SLAVE" ]
then
    echo `date` : Creating foreign key constraints
    ./admin/psql READWRITE <./admin/sql/CreateFKConstraints.sql
    ./admin/psql RAWDATA <./admin/sql/vertical/rawdata/CreateFKConstraints.sql
    echo `date` : Creating triggers
    ./admin/psql READWRITE <./admin/sql/CreateTriggers.sql
fi

echo `date` : Creating indexes
./admin/psql READWRITE <./admin/sql/CreateIndexes.sql
./admin/psql RAWDATA <./admin/sql/vertical/rawdata/CreateIndexes.sql

echo `date` : Creating search indexes
./admin/psql READWRITE <./admin/sql/CreateSearchIndexes.sql

echo `date` : Fixing sequences
./admin/psql READWRITE <./admin/sql/SetSequences.sql
./admin/psql RAWDATA <./admin/sql/vertical/rawdata/SetSequences.sql

echo 'VACUUM ANALYZE;' | ./admin/psql READWRITE
echo 'VACUUM ANALYZE;' | ./admin/psql RAWDATA

echo `date` : Done

# eof
