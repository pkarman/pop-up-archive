[![Stories in Ready](https://badge.waffle.io/popuparchive/pop-up-archive.png)](https://waffle.io/popuparchive/pop-up-archive)  
# Pop Up Archive

[![Build Status](https://travis-ci.org/popuparchive/pop-up-archive.png?branch=master)](https://travis-ci.org/popuparchive/pop-up-archive)
[![Dependency Status](https://gemnasium.com/popuparchive/pop-up-archive.png)](https://gemnasium.com/popuparchive/pop-up-archive)
[![Coverage Status](https://coveralls.io/repos/popuparchive/pop-up-archive/badge.png)](https://coveralls.io/r/popuparchive/pop-up-archive)
[![Code Climate](https://codeclimate.com/github/popuparchive/pop-up-archive.png)](https://codeclimate.com/github/popuparchive/pop-up-archive)

<table>
  <tr>
    <th>
      Ruby Version
    </th>
    <td>
      2.0.0
    </td>
  </tr>
  <tr>
    <th>
      Rails Version
    </th>
    <td>
      4.2.1
    </td>
  </tr>
  <tr>
    <th>
      Production Deployment
    </th>
    <td>
      git@heroku.com:pop-up-archive.git - http://pop-up-archive.herokuapp.com
    </td>
  </tr>
</table>

### Recommended setup

This guide expects that you have git and homebrew installed, and have a ruby environment set up with 2.0.0-p247 (using RVM or rbenv). We also assume you are using Pow, and have the development site running at http://pop-up-archive.dev. This is not required, but some aspects of the guide may not be appropriate for different configurations.

On OS X:

    brew install redis elasticsearch postgres
    git clone git@github.com:popuparchive/pop-up-archive.git
    curl get.pow.cx | sh
    gem install powder bundler
    cd pop-up-archive
    bundle install
    powder link
    cp config/env_vars.example config/env_vars

On Ubuntu:

    sudo apt-get install imagemagick libmagickwand-dev libxslt-dev postgresql libpq-dev nodejs npm
    git clone git@github.com:popuparchive/pop-up-archive.git
    gem install bundler
    cd pop-up-archive
    bundle install
    cp config/env_vars.example config/env_vars
    

#### Environment variables

In order to mimic the way Heroku works, many application configuration settings are defined with environment variables. If you are using foreman/etc you may have a different way of accomplishing this. You can also use the included support for the config/env_vars file.

##### You should not check config/env_vars into source control

You will need to set the SECRET_TOKEN value for the app to start (the default value is too short). The other default value may not be required. If need to point the app to a database or database user different than what is in the included database.yml, you should do that with an environment variable. Once complete:

    bundle exec rake db:create
    rake db:setup

If you receive a Postgres connection error or role error, you may need to create a Postgres user: 

    createuser -s -r <USERNAME FROM database.yml>
    
### Development

    powder open

The site should now be running. If you need to use sidekiq, or elasticsearch, you may need to start other services manually.

#### Loading a database dump

If you want to debug production issues on your development machine, grab a dump from heroku, or have someone with the necessary access rights do that for you, by running:

```
$ heroku pgbackups:capture
$ curl -o latest.dump `heroku pgbackups:url`
```

#### Rebuilding elasticsearch index

After loading new data from a db dump or performing a similar operation, you will need to rebuild the elasticsearch index. 

To do this run:

```
$ rake search:index
```

That will invoke the rake task in `lib/tasks/search.rake`.

### Testing

All that should be required is running `guard` in the project root. You can also just run `rake`.

We have the project on Travis-CI. If you submit a pull request, I assume it should check on that. I don't know.

NOTE that the Elasticsearch tests require that port 9250 is available on localhost. If you are running tests
on a Linux box, for example, you may need to alter iptables or other firewall service to open that port.


### Copyright & License

The Pop Up Archive software is released under the [Affero GNU General Public License](http://www.gnu.org/licenses/agpl.html).

Copyright (c) 2013 The Public Radio Exchange, www.prx.org

This program is free software: you can redistribute it and/or modify
it under the terms of the Affero GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
Affero GNU General Public License for more details.

You should have received a copy of the Affero GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
