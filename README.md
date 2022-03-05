# food.araines.net

Static serverless WordPress site for food/recipes

Based heavily on the [terraform-aws-serverless-static-wordpress](https://github.com/TechToSpeech/terraform-aws-serverless-static-wordpress) project. The related [blog post](https://www.techtospeech.com/serverless-static-wordpress-on-aws-for-0-01-a-day/) describes the project in detail.

## Initial setup

1. Initialise terraform

```
terraform init
```

2. Set up initial WordPress build

```
terraform apply
```

3. Start up WordPress (see below) and navigate to the admin interface

4. Install and activate the `wp-recipe-maker` recipe plugin

5. Configure the recipe plugin via the WP Recipe Maker menu item

6. Install and activate the `Fooding` theme

7. Go to Settings->Permalinks and select Post Name

8. Go to Settings->General and configure timezones, language etc

9. Install and activate `Yoast SEO` plugin (consider Rank Math?)

## Starting / stopping WordPress

To start up WordPress:

```
terraform apply -var="launch=1"
```

To shut down WordPress:

```
terraform apply
```

## Site publication

### First-time Setup

1. Login to `wp-admin`.

2. Go to WP2Static->Options and update the deployment URL to `https://food.araines.net`, then Save Options.

3. Go to WP2Static->Addons and enable the S3 deployment addon.

4. Click the settings cog and change the Object ACL to `private`, then Save S3 Options.

### Normal publication

To publish the site statically, login to `wp-admin`, then go to WP2Static and press Generate Static Site.

## Accessing WordPress

Go to the WordPress dynamic website at [wordpress.food.araines.net](http://wordpress.food.araines.net).

The admin interface can be accessed by [wp-admin](http://wordpress.food.araines.net/wp-admin).

## Troubleshooting

### Generate static site: Unable to fetch URL contents

During the static site generation, if it gets a 500 error with the last log being "Unable to fetch URL contents" then try clearing the caches.
