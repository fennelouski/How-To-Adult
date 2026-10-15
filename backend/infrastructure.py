"""CloudFormation and Vercel artifacts built from one committed source revision."""
import hashlib
import json
from pathlib import Path
import re
from urllib.parse import urlsplit

BACKEND = Path(__file__).resolve().parent


def template(revision, handler_source=None):
    if not re.fullmatch(r"[0-9a-f]{40}", revision):
        raise ValueError("Use the full committed Git SHA.")
    ref = lambda name: {"Ref": name}
    arn = lambda name: {"Fn::GetAtt": [name, "Arn"]}
    sub = lambda value: {"Fn::Sub": value}
    resources = {
        "Catalog": {"Type": "AWS::S3::Bucket", "DeletionPolicy": "Retain", "UpdateReplacePolicy": "Retain", "Properties": {
            "VersioningConfiguration": {"Status": "Enabled"},
            "BucketEncryption": {"ServerSideEncryptionConfiguration": [{"ServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]},
            "OwnershipControls": {"Rules": [{"ObjectOwnership": "BucketOwnerEnforced"}]},
            "PublicAccessBlockConfiguration": {"BlockPublicAcls": True, "BlockPublicPolicy": True, "IgnorePublicAcls": True, "RestrictPublicBuckets": True},
            "Tags": [{"Key": "Data", "Value": "public-editorial-guides-only"}]}},
        "BucketPolicy": {"Type": "AWS::S3::BucketPolicy", "Properties": {"Bucket": ref("Catalog"), "PolicyDocument": {"Version": "2012-10-17", "Statement": [
            {"Effect": "Deny", "Principal": "*", "Action": "s3:*", "Resource": [arn("Catalog"), sub("${Catalog.Arn}/*")], "Condition": {"Bool": {"aws:SecureTransport": "false"}}},
            {"Effect": "Deny", "Principal": "*", "Action": "s3:PutObject", "Resource": sub("${Catalog.Arn}/published/*"),
                "Condition": {"Null": {"s3:if-match": "true", "s3:if-none-match": "true"}, "Bool": {"s3:ObjectCreationOperation": "true"}}},
            {"Effect": "Deny", "Principal": "*", "Action": "s3:PutObject", "Resource": [sub("${Catalog.Arn}/revisions/*"), sub("${Catalog.Arn}/assets/*"), sub("${Catalog.Arn}/illustrations/*")],
                "Condition": {"Null": {"s3:if-none-match": "true"}, "Bool": {"s3:ObjectCreationOperation": "true"}}}
        ]}}},
        "Logs": {"Type": "AWS::Logs::LogGroup", "Properties": {"LogGroupName": sub("/aws/lambda/${AWS::StackName}-catalog"), "RetentionInDays": 7}},
        "Role": {"Type": "AWS::IAM::Role", "Properties": {
            "AssumeRolePolicyDocument": {"Version": "2012-10-17", "Statement": [{"Effect": "Allow", "Principal": {"Service": "lambda.amazonaws.com"}, "Action": "sts:AssumeRole"}]},
            "Policies": [{"PolicyName": "catalog-only", "PolicyDocument": {"Version": "2012-10-17", "Statement": [
                # GetObject needs bucket ListBucket permission to report a missing
                # first publication as NoSuchKey rather than AccessDenied. Its
                # request has no s3:prefix context; limit this grant to this bucket.
                {"Effect": "Allow", "Action": "s3:ListBucket", "Resource": arn("Catalog")},
                {"Effect": "Allow", "Action": ["s3:GetObject", "s3:PutObject"], "Resource": [sub("${Catalog.Arn}/published/*"), sub("${Catalog.Arn}/revisions/*"), sub("${Catalog.Arn}/assets/*"), sub("${Catalog.Arn}/illustrations/*")]},
                {"Effect": "Allow", "Action": ["logs:CreateLogStream", "logs:PutLogEvents"], "Resource": sub("arn:${AWS::Partition}:logs:${AWS::Region}:${AWS::AccountId}:log-group:/aws/lambda/${AWS::StackName}-catalog:*")}
            ]}}]}},
        "Function": {"Type": "AWS::Lambda::Function", "DependsOn": "Logs", "Properties": {
            "FunctionName": sub("${AWS::StackName}-catalog"), "Runtime": "python3.13", "Architectures": ["arm64"], "Handler": "index.main", "Role": arn("Role"),
            "Code": {"ZipFile": (BACKEND / "handler.py").read_text() if handler_source is None else handler_source}, "MemorySize": 256, "Timeout": 20,
            "Environment": {"Variables": {"CATALOG_BUCKET": ref("Catalog"), "SOURCE_REVISION": revision, "EDITOR_KEY_SHA256": ref("EditorKeySHA256")}},
            "Tags": [{"Key": "SourceRevision", "Value": revision}]}},
        "Api": {"Type": "AWS::ApiGatewayV2::Api", "Properties": {"Name": sub("${AWS::StackName}"), "ProtocolType": "HTTP"}},
        "Integration": {"Type": "AWS::ApiGatewayV2::Integration", "Properties": {"ApiId": ref("Api"), "IntegrationType": "AWS_PROXY", "IntegrationUri": arn("Function"), "PayloadFormatVersion": "2.0", "TimeoutInMillis": 21000}},
        "Permission": {"Type": "AWS::Lambda::Permission", "Properties": {"Action": "lambda:InvokeFunction", "FunctionName": arn("Function"), "Principal": "apigateway.amazonaws.com", "SourceArn": sub("arn:${AWS::Partition}:execute-api:${AWS::Region}:${AWS::AccountId}:${Api}/*")}},
        "Stage": {"Type": "AWS::ApiGatewayV2::Stage", "DependsOn": ["Health", "ReadCatalog", "SearchArticles", "ReadArticle", "Publication", "EditorStatus", "EditorGuides", "EditorAssets", "ReadAssets", "ReadIllustrations", "ReadIllustrationRevision"], "Properties": {
            "ApiId": ref("Api"), "StageName": "$default", "AutoDeploy": True,
            "DefaultRouteSettings": {"ThrottlingBurstLimit": 30, "ThrottlingRateLimit": 15},
            "RouteSettings": {route: {"ThrottlingBurstLimit": 2, "ThrottlingRateLimit": 1} for route in ("PUT /v1/publication", "POST /v1/editor/guides", "PUT /v1/editor/assets/{sha256}")}}}
    }
    for name, route in (("Health", "GET /health"), ("ReadCatalog", "GET /v1/catalog"), ("SearchArticles", "GET /v1/articles"), ("ReadArticle", "GET /v1/articles/{id}"), ("Publication", "PUT /v1/publication"), ("EditorStatus", "GET /v1/editor/status"), ("EditorGuides", "POST /v1/editor/guides"), ("EditorAssets", "PUT /v1/editor/assets/{sha256}"), ("ReadAssets", "GET /v1/assets/{sha256}"), ("ReadIllustrations", "GET /v1/illustrations"), ("ReadIllustrationRevision", "GET /v1/illustrations/{revision}")):
        resources[name] = {"Type": "AWS::ApiGatewayV2::Route", "Properties": {
            "ApiId": ref("Api"), "RouteKey": route, "AuthorizationType": "AWS_IAM" if name == "Publication" else "NONE",
            "Target": {"Fn::Join": ["/", ["integrations", ref("Integration")]]}}}
    return {"AWSTemplateFormatVersion": "2010-09-09", "Description": "How to Adult editorial guide library. AWS is the only publication store; no personal user data or scheduled generator.",
        "Parameters": {"EditorKeySHA256": {"Type": "String", "NoEcho": True, "Default": "", "AllowedPattern": "^([0-9a-f]{64})?$", "Description": "SHA-256 of the content-only Bearer key; empty disables editing."}},
        "Resources": resources, "Outputs": {
            "ApiURL": {"Value": sub("https://${Api}.execute-api.${AWS::Region}.${AWS::URLSuffix}")},
            "CatalogBucket": {"Value": ref("Catalog")}, "FunctionName": {"Value": ref("Function")},
            "PublisherResourceArn": {"Value": sub("arn:${AWS::Partition}:execute-api:${AWS::Region}:${AWS::AccountId}:${Api}/*/PUT/v1/publication")}}}


def vercel_output(api_url, revision, target, handler_sha256=None, artifact_snapshot=None):
    parsed = urlsplit(api_url)
    if parsed.scheme != "https" or not re.fullmatch(r"[a-z0-9]+\.execute-api\.[a-z0-9-]+\.amazonaws\.com", parsed.hostname or "") or parsed.path or parsed.query or parsed.fragment or parsed.username or parsed.password or parsed.port is not None:
        raise ValueError("Use the verified AWS HTTP API origin without a path.")
    if not re.fullmatch(r"[0-9a-f]{40}", revision):
        raise ValueError("Use the full committed Git SHA.")
    target = Path(target)
    build = target / ".vercel" / "output"
    (build / "static").mkdir(parents=True, exist_ok=True)

    def write_artifact(path, value):
        data = value.encode("utf-8")
        path.write_bytes(data)
        if artifact_snapshot is not None:
            artifact_snapshot[path] = hashlib.sha256(data).hexdigest()

    routes = [
        {"src": "^/(health|v1/catalog|v1/articles|v1/articles/[a-z0-9]+(?:-[a-z0-9]+)*|v1/illustrations|v1/illustrations/[A-Za-z0-9][A-Za-z0-9._-]{0,95}|v1/assets/[0-9a-f]{64}|v1/editor/status)$", "methods": ["GET"], "dest": api_url + "/$1"},
        {"src": "^/(v1/editor/guides)$", "methods": ["POST"], "dest": api_url + "/$1"},
        {"src": "^/(v1/editor/assets/[0-9a-f]{64})$", "methods": ["PUT"], "dest": api_url + "/$1"},
        {"handle": "filesystem"},
        {"src": "/.*", "status": 404}
    ]
    write_artifact(build / "config.json", json.dumps({"version": 3, "routes": routes}, indent=2) + "\n")
    release = {"sourceRevision": revision, "handlerSHA256": handler_sha256 or hashlib.sha256((BACKEND / "handler.py").read_bytes()).hexdigest(),
               "dataOwner": "AWS", "publicationGateway": "AWS IAM full publication; content-only Bearer editor", "scheduledGeneration": False}
    write_artifact(build / "static" / "release.json", json.dumps(release, indent=2) + "\n")
    write_artifact(build / "static" / "index.html", "<!doctype html><html lang=en><meta charset=utf-8><meta name=robots content=noindex><title>How to Adult guide library</title><body><p>How to Adult public guide library.</p></body></html>\n")
    write_artifact(target / "vercel.json", json.dumps({"git": {"deploymentEnabled": False}}, indent=2) + "\n")
    return release
