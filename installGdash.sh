apt-get -y --force-yes install git unzip curl vim ttf-droid varnish
curl -L get.rvm.io | bash -s stable
source /etc/profile.d/rvm.sh
rvm requirements
rvm install 1.9.3
rvm use 1.9.3
rvm 1.9.3 --default
cd /opt
git clone https://github.com/GermanG/gdash.git
cd /opt/gdash
bundle install
gem install passenger
apt-get -y --force-yes install libcurl4-openssl-dev apache2-mpm-worker apache2-threaded-dev libapr1-dev libaprutil1-dev
passenger-install-apache2-module -a

# Create /etc/apache2/mods-available/passenger.load and include:
cat > /etc/apache2/mods-available/passenger.load <<END_CONF
LoadModule passenger_module $( echo /usr/local/rvm/gems/ruby-1.9.3-p*/gems/passenger-*/buildout/apache2/mod_passenger.so)
END_CONF
 
# Then create /etc/apache2/mods-available/passenger.conf
cat > /etc/apache2/mods-available/passenger.conf <<END_CONF
PassengerRoot $(echo /usr/local/rvm/gems/ruby-1.9.3-p*/gems/passenger-*)
PassengerRuby $(echo /usr/local/rvm/wrappers/ruby-1.9.3-p[0-9][0-9]?/ruby)
END_CONF
 
# Symlink passenger.conf and passenger.load to /etc/apache2/mods-enabled/
a2enmod passenger
 
# Update your app's apache config in /etc/apache2/sites-available/appname with something similar to the following:

cat > /etc/apache2/sites-available/gdash <<EOF
<VirtualHost *:8080>
	ServerName gdash
	ServerAdmin webmaster@localhost

        DocumentRoot /var/www/
        RackBaseURI /gdash

 	RedirectMatch "^/* *$" /gdash

        <Directory /var/www/gdash>
            Order allow,deny
            Allow from all
            AllowOverride All
            Options -MultiViews
        </Directory>

</VirtualHost>
EOF

a2ensite gdash

ln -s /opt/gdash/public /var/www/gdash

cat > /opt/gdash/config/gdash.yaml << EOF
:graphite: http://localhost
:templatedir: /opt/gdash/graph_templates
#:username: admin
#:password: secret
:options:
  :title: Graphite Dasboard
  :prefix: "/gdash"
  :refresh_rate: 60
  :graph_columns: 2
  :graph_width: 600
  :graph_height: 250
  :interval_filters:
    - :label: Last Hour
      :from: -1hour
      :to: now
    - :label: Last 8 Hours
      :from: -8hour
      :to: now
    - :label: Last Day
      :from: -1day
    - :label: Last Week
      :from: -8day
    - :label: Last Month
      :from: -1month
    - :label: Last Year
      :from: -1year
  :intervals:
    - [ "-1hour", "1 hour" ]
    - [ "-8hour", "8 hour" ]
    - [ "-1day", "1 day" ]
    - [ "-8day", "1 week" ]
    - [ "-1month", "1 month" ]
    - [ "-1year", "1 year" ]

EOF


patch /usr/local/rvm/gems/ruby-1.9.3-p*/gems/graphite_graph-0.0.8/lib/graphite_graph.rb << EOF
--- /usr/local/rvm/gems/ruby-1.9.3-p448/gems/graphite_graph-0.0.8/lib/graphite_graph.rb	2013-09-06 16:15:50.715676000 +0000
+++ x.rb	2013-09-06 16:17:02.787624488 +0000
@@ -293,6 +293,8 @@
     url_parts << "logBase=#{properties[:logbase]}" if properties[:logbase]
     url_parts << "areaAlpha=#{properties[:area_alpha]}" if properties[:area_alpha]
 
+    @properties[:target] = []
+
     target_order.each do |name|
       target = targets[name]
 
@@ -350,6 +352,8 @@
         end
 
         url_parts << "target=#{graphite_target}"
+
+        @properties[:target] << graphite_target
       end
     end
EOF

cd /opt/gdash/public
git clone https://github.com/GermanG/timeserieswidget.git
cd timeserieswidget
git submodule update --init

cat > /etc/apache2/ports.conf <<EOF
# If you just change the port or add more ports here, you will likely also
# have to change the VirtualHost statement in
# /etc/apache2/sites-enabled/000-default
# This is also true if you have upgraded from before 2.2.9-3 (i.e. from
# Debian etch). See /usr/share/doc/apache2.2-common/NEWS.Debian.gz and
# README.Debian.gz

NameVirtualHost *:8080
Listen 8080

<IfModule mod_ssl.c>
    # If you add NameVirtualHost *:443 here, you will also have to change
    # the VirtualHost statement in /etc/apache2/sites-available/default-ssl
    # to <VirtualHost *:443>
    # Server Name Indication for SSL named virtual hosts is currently not
    # supported by MSIE on Windows XP.
    Listen 443
</IfModule>

<IfModule mod_gnutls.c>
    Listen 443
</IfModule>
EOF

service apache2 reload

cat > /etc/varnish/default.vcl <<EOF
backend default {
    .host = "127.0.0.1";
    .port = "8080";
}
EOF

service varnish restart
