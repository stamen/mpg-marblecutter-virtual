# mpg-marblecutter-virtual

*Originally based on [marblecutter-virtual](https://github.com/mojodna/marblecutter-virtual).*

I am a tile server for HTTP(S)-accessible [Cloud Optimized GeoTIFFs
(COGs)](http://www.cogeo.org/).

I can also be seen as an example of a virtual `Catalog` implementation, drawing
necessary metadata from URL parameters. For more information, check out [`VirtualCatalog`](virtual/catalogs.py) and [`web.py`](virtual/web.py).

## Running Locally

The easiest way to get a working instance running locally is to use [Docker
Compose](https://docs.docker.com/compose/):

```bash
docker-compose up
```

A tile server will then be accessible on `localhost:8000`. To browse a map
preview, visit
`http://localhost:8000/preview?url=https%3A%2F%2Fs3.amazonaws.com%2Ftiles.mpgranch.com%2Fsources%2F2017c_jan18clip_cloudoptimized.tif`

URLs (`url` in the query string) must be URL-encoded. From a browser's
JavaScript console (or Node.js REPL), run:

```javascript
encodeURIComponent("https://s3.amazonaws.com/tiles.mpgranch.com/sources/2017c_jan18clip_cloudoptimized.tif")
```

If you need to access non-public files on S3, set your environment accordingly
(see `sample.env`), either by creating `.env` and uncommenting `env_file` in
`docker-compose.yml` or by adding appropriate `environment` entries.

## Endpoints

### `/bounds` - Source image bounds (in geographic coordinates)

#### Parameters

* `url` - a URL to a valid COG. Required.

#### Example

```bash
$ curl "http://localhost:8000/bounds?url=http://localhost:8000/preview?url=https%3A%2F%2Fs3.amazonaws.com%2Ftiles.mpgranch.com%2Fsources%2F2017c_jan18clip_cloudoptimized.tif"
{
  "bounds": [
    -114.0598676519122,
    46.65466452757754,
    -113.9039579851515,
    46.78638812429985
  ],
  "url": "https://s3.amazonaws.com/tiles.mpgranch.com/sources/2017c_jan18clip_cloudoptimized.tif"
}
```

### `/tiles/{z}/{x}/{y}` - Tiles

#### Parameters

* `url` - a URL to a valid COG. Required.
* `rgb` - Source bands to map to RGB channels. Defaults to `1,2,3`.
* `nodata` - a custom NODATA value.
* `linearStretch` - whether to stretch output to match min/max values present in
  the source. Useful for raw sensor output, e.g. earth observation (EO) data.
* `resample` - Specify a custom resampling method (e.g. for discrete values).
  Valid values (from `rasterio.enums.Resampling`): `nearest`, `bilinear`,
  `cubic`, `cubic_spline`, `lanczos`, `average`, `mode`, `gauss`, `max`, `min`,
  `med`, `q1`, `q3`. Defaults to `bilinear`.

`@2x` can be added to the filename (after the `{y}` coordinate) to request
retina tiles. The map preview will detect support for retina displays and
request tiles accordingly.

PNGs or JPEGs will be rendered depending on the presence of NODATA values in the
source image (surfaced as transparency in the output).

#### Examples

```bash
$ curl "http://localhost:8000/tiles/14/3851/6812@2x?url=https%3A%2F%2Fs3.amazonaws.com%2Ftiles.mpgranch.com%2Fsources%2F2017c_jan18clip_cloudoptimized.tif" | imgcat
```

![RGB](docs/rgb.png)

```bash
$ curl "http://localhost:8000/tiles/14/3851/6812@2x?url=https%3A%2F%2Fs3.amazonaws.com%2Ftiles.mpgranch.com%2Fsources%2F2017c_jan18clip_cloudoptimized.tif&rgb=1,1,1" | imgcat
```

![greyscale](docs/greyscale.png)

```bash
$ curl "http://localhost:8000/tiles/14/3851/6812@2x?url=https%3A%2F%2Fs3.amazonaws.com%2Ftiles.mpgranch.com%2Fsources%2F2017c_jan18clip_cloudoptimized.tif&rgb=1,1,1&linearStretch=true" | imgcat
```

![greyscale stretched](docs/greyscale_stretched.png)

### `/tiles` - TileJSON

#### Parameters

See tile parameters.

#### Example

```bash
$ curl "http://localhost:8000/tiles?url=https%3A%2F%2Fs3.amazonaws.com%2Ftiles.mpgranch.com%2Fsources%2F2017c_jan18clip_cloudoptimized.tif"
{
  "bounds": [
    -95.46993599071261,
    28.86905396361014,
    -95.2386152334213,
    29.068190805522605
  ],
  "center": [
    -95.35427561206696,
    28.968622384566373,
    15
  ],
  "maxzoom": 21,
  "minzoom": 8,
  "name": "Untitled",
  "tilejson": "2.1.0",
  "tiles": [
    "//localhost:8000/tiles/{z}/{x}/{y}?url=https%3A%2F%2Fs3.amazonaws.com%2Ftiles.mpgranch.com%2Fsources%2F2017c_jan18clip_cloudoptimized.tif"
  ]
}
```

### `/preview` - Preview

#### Parameters

See tile parameters.

#### Example

`http://localhost:8000/preview?url=https%3A%2F%2Fs3.amazonaws.com%2Ftiles.mpgranch.com%2Fsources%2F2017c_jan18clip_cloudoptimized.tif`

## Deploying to AWS

### Old instructions

Requires [apex up](https://github.com/apex/up). The first time you deploy, make an `up.json` file:

```bash
cp up.json.example up.json
```

Edit `up.json` to use the `profile` name for an AWS configuration profile (typically stored in `$HOME/.aws/credentials`).

To deploy to staging:

```bash
make deploy-up
```

### New instructions

marblecutter-virtual is deployed using the [AWS Serverless Application Model
(SAM)](https://github.com/awslabs/serverless-application-model).

Once you have the [SAM CLI](https://github.com/awslabs/aws-sam-cli) installed, you can build with:

```bash
sam build --use-container
```

You can then test it locally as though it's running on Lambda + API Gateway
(it will be _really_ slow, as function invocations are not re-used in the
same way as on Lambda proper):

```bash
sam local start-api
```

To deploy, first package the application:

```bash
sam package --s3-bucket <staging-bucket> --output-template-file packaged.yaml
```

Once staged, it can be deployed:

```bash
sam deploy \
  --template-file packaged.yaml \
  --stack-name marblecutter-virtual \
  --capabilities CAPABILITY_IAM \
  --parameter-overrides DomainName=<hostname>
```

These commands are wrapped as a `deploy` target, so this can be done more
simply with:

```bash
S3_BUCKET=<staging-bucket> DOMAIN_NAME=<hostname> make deploy
```

`<staging-bucket>` must be in the target AWS region (`AWS_DEFAULT_REGION`).

NOTE: when setting up a Cloudfront distribution in front of a regional API
Gateway endpoint (which is what this process does), an `Origin Custom Header`
will be added: `X-Forwarded-Host` should be the hostname used for your
Cloudfront distribution (otherwise auto-generated tile URLs will use the API
Gateway domain; CF sends a `Host` header corresponding to the origin, not the
CDN endpoint).
