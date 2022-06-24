# Github Actions for Elasticsearch/Kibana Docker Images

Run a nightly action (scheduled every 2AM UTC) that will:

 - Fetch list of all elasticsearch/kibana image tags and filter/identify latest major versions (> 7.17.4)
 - Pull images for each latest major versions (from `library/elasticsearch` and `library/kibana` official repositories)
 - Add semantic version tags for each image
 	- e.g. `elasticsearch:8.2.3` image will be tagged with `8.2.3`, `8.2` and `8` tags
 - Push images to `jahia/elasticsearch` and `jahia/kibana` docker repositories

Github action can also be triggered with a manual workflow if needed. There is also an optional `DRY_RUN=true` parameter to run the script without pushing to the jahia repository for testing purposes.
