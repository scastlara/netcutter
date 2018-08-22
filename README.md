<img width="350" src="https://rawgit.com/scastlara/netcutter/master/netcutter-icon.png"/>


-----

Disentangle protein-protein interactions networks by using a list of driver genes as baits, separating the network in different levels, each one of them more relevant to the drivers.

Netcutter automatically creates a neo4j database with all the protein networks and serves a web application for users to explore the different levels by using docker.

## Configuration file

`netcutter` needs a netengine config file in order to compute the graphs and build the database/website. In this configuration file one has to set the necessary parameters and options for `build.py` to work. The syntax goes as follows:

```
# Comment
parameter=value
another_parameter=another_value
```

The parameters are the following:

* project_name
* output
* neo4j_memory
* neo4j_address
* biogrid_file
* string_file
* ppaxe_file
* drivers_file
* alias_file
* web_address
* content_templates
* logo_img

