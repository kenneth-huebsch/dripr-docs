# Dripr Documentation

This repository contains the documentation site for [Dripr.ai](https://www.dripr.ai/).

## Structure

```
dripr-docs/
├── index.md                    # Home page
├── _config.yml                 # Jekyll configuration
├── api/                        # API documentation
│   ├── index.md               # API overview and version listing
│   └── v1/                    # Version 1 API endpoints
│       └── local-market-data.md
├── resources/                  # Additional resources
│   └── roadmap.md             # Product roadmap
├── assets/                     # Static assets
│   ├── images/                # Image files
│   └── diagrams/              # Diagrams and charts
└── _data/                      # Jekyll data files
    └── navigation.yml         # Site navigation structure
```

## Adding New Content

### Adding a New API Endpoint

1. Create a new markdown file in `api/v1/[endpoint-name].md`
2. Update `api/index.md` to include the new endpoint
3. Update `_data/navigation.yml` to add navigation link

### Adding a New API Version

1. Create a new directory `api/v2/`
2. Add endpoint documentation files
3. Update `api/index.md` to list the new version
4. Update `_data/navigation.yml`

### Adding Resources

Add new resource files to the `resources/` directory and update navigation accordingly.

## Building Locally

This is a Jekyll site. To build locally:

```bash
bundle install
bundle exec jekyll serve
```

Visit `http://localhost:4000/dripr-docs/` to view the site.

## Deployment

This site is configured to deploy to GitHub Pages at:
https://kenneth-huebsch.github.io/dripr-docs/

## Development
docker run --rm -v ${PWD}:/srv/jekyll -p 4000:4000 jekyll/jekyll:latest sh -c "bundle install && jekyll serve --baseurl '' --host 0.0.0.0"
