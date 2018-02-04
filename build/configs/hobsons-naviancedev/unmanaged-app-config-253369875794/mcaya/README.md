Simple set of templates for all the services.naviance.com PHP applications outside of succeed and succeed-legacy

All *.j2 files are bases for jinja2 templates, but have no attempts to name the replacement parameters.  All are currently `{{ TDB }}`

All *.ini files require no parameter substitution in qa, staging, or prod.

Pattern:
<repo>/path/to/config/file

Example: for 'assessment-api-prototype'

`assessment-api-prototype/resources/config/services.json.dist.j2` copies to `<build-package-root>/resources/config/services.json.dist`

File List:
```
assessment-api-prototype/resources/config/services.json.dist.j2
legacy-nav-api-v1/application/config/application.ini
legacy-nav-api-v1/core/config/config.xml.j2
legacy-nav-api-v2/application/config/application.ini
legacy-nav-api-v2/application/config/config.xml.j2
legacy-naviance-student-mobile-api/application/config/application.ini
legacy-naviance-student-mobile-api/core/config/config.xml.j2
naviance-auth-bridge/app/config/parameters.yml.j2
naviance-student-college-bridge/app/config/parameters.yml.j2
```