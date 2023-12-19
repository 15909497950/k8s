# k8s 部署 sentry

## 1.准备sentry.yaml

```yaml
---
# Source: sentry/templates/serviceaccount.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ak-sentry
  labels:
    app: ak-sentry
    chart: "sentry-4.3.3"
    release: "ak"
    heritage: "Helm"
---
# Source: sentry/charts/postgresql/templates/secrets.yaml
apiVersion: v1
kind: Secret
metadata:
  name: ak-sentry-postgresql
  labels:
    app: sentry-postgresql
    chart: postgresql-6.5.0
    release: "ak"
    heritage: "Helm"
type: Opaque
data:
  postgresql-password: "cG9zdGdyZXM="
---
# Source: sentry/charts/redis/templates/secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: ak-sentry-redis
  labels:
    app: sentry-redis
    chart: redis-9.3.2
    release: "ak"
    heritage: "Helm"
type: Opaque
data:
  redis-password: "aGFFY0t4VWZlYw=="
---
# Source: sentry/templates/secrets.yaml
apiVersion: v1
kind: Secret
metadata:
  name: ak-sentry
  labels:
    app: ak-sentry
    chart: "sentry-4.3.3"
    release: "ak"
    heritage: "Helm"
type: Opaque
data:
  
  sentry-secret: "S0UwanVsNlNFQXkwc2dxNGRQc1UzNzBHbDJpOFpIQ0V5a29BbDY2Sw=="
  
  smtp-password: ""
  
  
  user-password: "YWRtaW4="
---
# Source: sentry/charts/redis/templates/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: ak-sentry-redis
  labels:
    app: sentry-redis
    chart: redis-9.3.2
    heritage: Helm
    release: ak
data:
  redis.conf: |-
    # User-supplied configuration:
    # Enable AOF https://redis.io/topics/persistence#append-only-file
    appendonly yes
    # Disable RDB persistence, AOF persistence already enabled.
    save ""
  master.conf: |-
    dir /data
    rename-command FLUSHDB ""
    rename-command FLUSHALL ""
  replica.conf: |-
    dir /data
    slave-read-only yes
    rename-command FLUSHDB ""
    rename-command FLUSHALL ""
---
# Source: sentry/charts/redis/templates/health-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: ak-sentry-redis-health
  labels:
    app: sentry-redis
    chart: redis-9.3.2
    heritage: Helm
    release: ak
data:
  ping_readiness_local.sh: |-
    response=$(
      timeout -s 9 $1 \
      redis-cli \
        -a $REDIS_PASSWORD --no-auth-warning \
        -h localhost \
        -p $REDIS_PORT \
        ping
    )
    if [ "$response" != "PONG" ]; then
      echo "$response"
      exit 1
    fi
  ping_liveness_local.sh: |-
    response=$(
      timeout -s 9 $1 \
      redis-cli \
        -a $REDIS_PASSWORD --no-auth-warning \
        -h localhost \
        -p $REDIS_PORT \
        ping
    )
    if [ "$response" != "PONG" ] && [ "$response" != "LOADING Redis is loading the dataset in memory" ]; then
      echo "$response"
      exit 1
    fi
  ping_readiness_master.sh: |-
    response=$(
      timeout -s 9 $1 \
      redis-cli \
        -a $REDIS_MASTER_PASSWORD --no-auth-warning \
        -h $REDIS_MASTER_HOST \
        -p $REDIS_MASTER_PORT_NUMBER \
        ping
    )
    if [ "$response" != "PONG" ]; then
      echo "$response"
      exit 1
    fi
  ping_liveness_master.sh: |-
    response=$(
      timeout -s 9 $1 \
      redis-cli \
        -a $REDIS_MASTER_PASSWORD --no-auth-warning \
        -h $REDIS_MASTER_HOST \
        -p $REDIS_MASTER_PORT_NUMBER \
        ping
    )
    if [ "$response" != "PONG" ] && [ "$response" != "LOADING Redis is loading the dataset in memory" ]; then
      echo "$response"
      exit 1
    fi
  ping_readiness_local_and_master.sh: |-
    script_dir="$(dirname "$0")"
    exit_status=0
    "$script_dir/ping_readiness_local.sh" $1 || exit_status=$?
    "$script_dir/ping_readiness_master.sh" $1 || exit_status=$?
    exit $exit_status
  ping_liveness_local_and_master.sh: |-
    script_dir="$(dirname "$0")"
    exit_status=0
    "$script_dir/ping_liveness_local.sh" $1 || exit_status=$?
    "$script_dir/ping_liveness_master.sh" $1 || exit_status=$?
    exit $exit_status
---
# Source: sentry/templates/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: ak-sentry
  labels:
    app: ak-sentry
    chart: "sentry-4.3.3"
    release: "ak"
    heritage: "Helm"
data:
  config.yml: |-
    # While a lot of configuration in Sentry can be changed via the UI, for all
    # new-style config (as of 8.0) you can also declare values here in this file
    # to enforce defaults or to ensure they cannot be changed via the UI. For more
    # information see the Sentry documentation.

    ###############
    # Mail Server #
    ###############

    # mail.backend: 'smtp'  # Use dummy if you want to disable email entirely
    # mail.host: 'localhost'
    # mail.port: 25
    # mail.username: ''
    # mail.password: ''
    # mail.use-tls: false
    # The email address to send on behalf of
    # mail.from: 'root@localhost'

    # If you'd like to configure email replies, enable this.
    # mail.enable-replies: false

    # When email-replies are enabled, this value is used in the Reply-To header
    # mail.reply-hostname: ''

    # If you're using mailgun for inbound mail, set your API key and configure a
    # route to forward to /api/hooks/mailgun/inbound/
    # mail.mailgun-api-key: ''

    ###################
    # System Settings #
    ###################

    # If this file ever becomes compromised, it's important to regenerate your a new key
    # Changing this value will result in all current sessions being invalidated.
    # A new key can be generated with `$ sentry config generate-secret-key`
    # system.secret-key: 'changeme'

    # The ``redis.clusters`` setting is used, unsurprisingly, to configure Redis
    # clusters. These clusters can be then referred to by name when configuring
    # backends such as the cache, digests, or TSDB backend.
    # redis.clusters:
    #   default:
    #     hosts:
    #       0:
    #         host: 127.0.0.1
    #         port: 6379

    ################
    # File storage #
    ################

    # Uploaded media uses these `filestore` settings. The available
    # backends are either `filesystem` or `s3`.

    filestore.backend: 'filesystem'
    filestore.options:
      location: '/var/lib/sentry/files'

    

    
  sentry.conf.py: |-
    # This file is just Python, with a touch of Django which means
    # you can inherit and tweak settings to your hearts content.

    # For Docker, the following environment variables are supported:
    #  SENTRY_POSTGRES_HOST
    #  SENTRY_POSTGRES_PORT
    #  SENTRY_DB_NAME
    #  SENTRY_DB_USER
    #  SENTRY_DB_PASSWORD
    #  SENTRY_RABBITMQ_HOST
    #  SENTRY_RABBITMQ_USERNAME
    #  SENTRY_RABBITMQ_PASSWORD
    #  SENTRY_RABBITMQ_VHOST
    #  SENTRY_REDIS_HOST
    #  SENTRY_REDIS_PASSWORD
    #  SENTRY_REDIS_PORT
    #  SENTRY_REDIS_DB
    #  SENTRY_MEMCACHED_HOST
    #  SENTRY_MEMCACHED_PORT
    #  SENTRY_FILESTORE_DIR
    #  SENTRY_SERVER_EMAIL
    #  SENTRY_EMAIL_HOST
    #  SENTRY_EMAIL_PORT
    #  SENTRY_EMAIL_USER
    #  SENTRY_EMAIL_PASSWORD
    #  SENTRY_EMAIL_USE_TLS
    #  SENTRY_EMAIL_LIST_NAMESPACE
    #  SENTRY_ENABLE_EMAIL_REPLIES
    #  SENTRY_SMTP_HOSTNAME
    #  SENTRY_MAILGUN_API_KEY
    #  SENTRY_SINGLE_ORGANIZATION
    #  SENTRY_SECRET_KEY
    #  (slack integration)
    #  SENTRY_SLACK_CLIENT_ID
    #  SENTRY_SLACK_CLIENT_SECRET
    #  SENTRY_SLACK_VERIFICATION_TOKEN
    #  (github plugin, sso)
    #  GITHUB_APP_ID
    #  GITHUB_API_SECRET
    #  (github integration)
    #  SENTRY_GITHUB_APP_ID
    #  SENTRY_GITHUB_APP_CLIENT_ID
    #  SENTRY_GITHUB_APP_CLIENT_SECRET
    #  SENTRY_GITHUB_APP_WEBHOOK_SECRET
    #  SENTRY_GITHUB_APP_PRIVATE_KEY
    #  (azure devops integration)
    #  SENTRY_VSTS_CLIENT_ID
    #  SENTRY_VSTS_CLIENT_SECRET
    #  (bitbucket plugin)
    #  BITBUCKET_CONSUMER_KEY
    #  BITBUCKET_CONSUMER_SECRET
    from sentry.conf.server import *  # NOQA
    from sentry.utils.types import Bool, Int

    import os
    import os.path
    import six

    CONF_ROOT = os.path.dirname(__file__)

    postgres = env('SENTRY_POSTGRES_HOST') or (env('POSTGRES_PORT_5432_TCP_ADDR') and 'postgres')
    if postgres:
        DATABASES = {
            'default': {
                'ENGINE': 'sentry.db.postgres',
                'NAME': (
                    env('SENTRY_DB_NAME')
                    or env('POSTGRES_ENV_POSTGRES_USER')
                    or 'postgres'
                ),
                'USER': (
                    env('SENTRY_DB_USER')
                    or env('POSTGRES_ENV_POSTGRES_USER')
                    or 'postgres'
                ),
                'PASSWORD': (
                    env('SENTRY_DB_PASSWORD')
                    or env('POSTGRES_ENV_POSTGRES_PASSWORD')
                    or ''
                ),
                'HOST': postgres,
                'PORT': (
                    env('SENTRY_POSTGRES_PORT')
                    or ''
                ),
            },
        }

    # You should not change this setting after your database has been created
    # unless you have altered all schemas first
    SENTRY_USE_BIG_INTS = True

    # If you're expecting any kind of real traffic on Sentry, we highly recommend
    # configuring the CACHES and Redis settings

    ###########
    # General #
    ###########

    # Instruct Sentry that this install intends to be run by a single organization
    # and thus various UI optimizations should be enabled.
    SENTRY_SINGLE_ORGANIZATION = env('SENTRY_SINGLE_ORGANIZATION', True)

    #########
    # Redis #
    #########

    # Generic Redis configuration used as defaults for various things including:
    # Buffers, Quotas, TSDB

    redis = env('SENTRY_REDIS_HOST') or (env('REDIS_PORT_6379_TCP_ADDR') and 'redis')
    if not redis:
        raise Exception('Error: REDIS_PORT_6379_TCP_ADDR (or SENTRY_REDIS_HOST) is undefined, did you forget to `--link` a redis container?')

    redis_password = env('SENTRY_REDIS_PASSWORD') or ''
    redis_port = env('SENTRY_REDIS_PORT') or '6379'
    redis_db = env('SENTRY_REDIS_DB') or '0'

    SENTRY_OPTIONS.update({
        'redis.clusters': {
            'default': {
                'hosts': {
                    0: {
                        'host': redis,
                        'password': redis_password,
                        'port': redis_port,
                        'db': redis_db,
                    },
                },
            },
        },
    })

    #########
    # Cache #
    #########

    # Sentry currently utilizes two separate mechanisms. While CACHES is not a
    # requirement, it will optimize several high throughput patterns.

    memcached = env('SENTRY_MEMCACHED_HOST') or (env('MEMCACHED_PORT_11211_TCP_ADDR') and 'memcached')
    if memcached:
        memcached_port = (
            env('SENTRY_MEMCACHED_PORT')
            or '11211'
        )
        CACHES = {
            'default': {
                'BACKEND': 'django.core.cache.backends.memcached.MemcachedCache',
                'LOCATION': [memcached + ':' + memcached_port],
                'TIMEOUT': 3600,
            }
        }

    # A primary cache is required for things such as processing events
    SENTRY_CACHE = 'sentry.cache.redis.RedisCache'

    #########
    # Queue #
    #########

    # See https://docs.getsentry.com/on-premise/server/queue/ for more
    # information on configuring your queue broker and workers. Sentry relies
    # on a Python framework called Celery to manage queues.

    rabbitmq = env('SENTRY_RABBITMQ_HOST') or (env('RABBITMQ_PORT_5672_TCP_ADDR') and 'rabbitmq')

    if rabbitmq:
        BROKER_URL = (
            'amqp://' + (
                env('SENTRY_RABBITMQ_USERNAME')
                or env('RABBITMQ_ENV_RABBITMQ_DEFAULT_USER')
                or 'guest'
            ) + ':' + (
                env('SENTRY_RABBITMQ_PASSWORD')
                or env('RABBITMQ_ENV_RABBITMQ_DEFAULT_PASS')
                or 'guest'
            ) + '@' + rabbitmq + '/' + (
                env('SENTRY_RABBITMQ_VHOST')
                or env('RABBITMQ_ENV_RABBITMQ_DEFAULT_VHOST')
                or '/'
            )
        )
    else:
        BROKER_URL = 'redis://:' + redis_password + '@' + redis + ':' + redis_port + '/' + redis_db


    ###############
    # Rate Limits #
    ###############

    # Rate limits apply to notification handlers and are enforced per-project
    # automatically.

    SENTRY_RATELIMITER = 'sentry.ratelimits.redis.RedisRateLimiter'

    ##################
    # Update Buffers #
    ##################

    # Buffers (combined with queueing) act as an intermediate layer between the
    # database and the storage API. They will greatly improve efficiency on large
    # numbers of the same events being sent to the API in a short amount of time.
    # (read: if you send any kind of real data to Sentry, you should enable buffers)

    SENTRY_BUFFER = 'sentry.buffer.redis.RedisBuffer'

    ##########
    # Quotas #
    ##########

    # Quotas allow you to rate limit individual projects or the Sentry install as
    # a whole.

    SENTRY_QUOTAS = 'sentry.quotas.redis.RedisQuota'

    ########
    # TSDB #
    ########

    # The TSDB is used for building charts as well as making things like per-rate
    # alerts possible.

    SENTRY_TSDB = 'sentry.tsdb.redis.RedisTSDB'

    ###########
    # Digests #
    ###########

    # The digest backend powers notification summaries.

    SENTRY_DIGESTS = 'sentry.digests.backends.redis.RedisBackend'

    ##############
    # Web Server #
    ##############

    # If you're using a reverse SSL proxy, you should enable the X-Forwarded-Proto
    # header and set `SENTRY_USE_SSL=1`

    if env('SENTRY_USE_SSL', False):
        SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')
        SESSION_COOKIE_SECURE = True
        CSRF_COOKIE_SECURE = True
        SOCIAL_AUTH_REDIRECT_IS_HTTPS = True

    SENTRY_WEB_HOST = '0.0.0.0'
    SENTRY_WEB_PORT = 9000
    SENTRY_WEB_OPTIONS = {
        'http': '%s:%s' % (SENTRY_WEB_HOST, SENTRY_WEB_PORT),
        'protocol': 'uwsgi',
        # This is need to prevent https://git.io/fj7Lw
        'uwsgi-socket': None,
        'http-keepalive': True,
        'memory-report': False,
        # 'workers': 3,  # the number of web workers
    }

    ###############
    # Mail Server #
    ###############

    email = env('SENTRY_EMAIL_HOST') or (env('SMTP_PORT_25_TCP_ADDR') and 'smtp')
    if email:
        SENTRY_OPTIONS['mail.backend'] = 'smtp'
        SENTRY_OPTIONS['mail.host'] = email
        SENTRY_OPTIONS['mail.from'] = env('SENTRY_SERVER_EMAIL')
        SENTRY_OPTIONS['mail.username'] = env('SENTRY_EMAIL_USER') or ''
        SENTRY_OPTIONS['mail.password'] = env('SENTRY_EMAIL_PASSWORD') or ''
        SENTRY_OPTIONS['mail.port'] = int(env('SENTRY_EMAIL_PORT') or 25)
        SENTRY_OPTIONS['mail.use-tls'] = env('SENTRY_EMAIL_USE_TLS', False)
        SENTRY_OPTIONS['mail.list-namespace'] = env('SENTRY_EMAIL_LIST_NAMESPACE') or 'localhost'
    else:
        SENTRY_OPTIONS['mail.backend'] = 'dummy'

    # The email address to send on behalf of
    SENTRY_OPTIONS['mail.from'] = env('SENTRY_SERVER_EMAIL') or 'root@localhost'
    # If you're using mailgun for inbound mail, set your API key and configure a
    # route to forward to /api/hooks/mailgun/inbound/
    SENTRY_OPTIONS['mail.mailgun-api-key'] = env('SENTRY_MAILGUN_API_KEY') or ''
    # If you specify a MAILGUN_API_KEY, you definitely want EMAIL_REPLIES
    if SENTRY_OPTIONS['mail.mailgun-api-key']:
        SENTRY_OPTIONS['mail.enable-replies'] = True
    else:
        SENTRY_OPTIONS['mail.enable-replies'] = env('SENTRY_ENABLE_EMAIL_REPLIES', False)
    if SENTRY_OPTIONS['mail.enable-replies']:
        SENTRY_OPTIONS['mail.reply-hostname'] = env('SENTRY_SMTP_HOSTNAME') or ''



    ##########
    # Docker #
    ##########

    # Docker's environment configuration needs to happen
    # prior to anything that might rely on these values to
    # enable more "smart" configuration.

    ENV_CONFIG_MAPPING = {
        'SENTRY_SECRET_KEY': 'system.secret-key',

        'SENTRY_SLACK_CLIENT_ID': 'slack.client-id',
        'SENTRY_SLACK_CLIENT_SECRET': 'slack.client-secret',
        'SENTRY_SLACK_VERIFICATION_TOKEN': 'slack.verification-token',

        'SENTRY_GITHUB_APP_ID': ('github-app.id', Int),
        'SENTRY_GITHUB_APP_CLIENT_ID': 'github-app.client-id',
        'SENTRY_GITHUB_APP_CLIENT_SECRET': 'github-app.client-secret',
        'SENTRY_GITHUB_APP_WEBHOOK_SECRET': 'github-app.webhook-secret',
        'SENTRY_GITHUB_APP_PRIVATE_KEY': 'github-app.private-key',

        'SENTRY_VSTS_CLIENT_ID': 'vsts.client-id',
        'SENTRY_VSTS_CLIENT_SECRET': 'vsts.client-secret',
        'GOOGLE_CLIENT_ID': 'auth-google.client-id',
        'GOOGLE_CLIENT_SECRET': 'auth-google.client-secret',
    }


    def bind_env_config(config=SENTRY_OPTIONS, mapping=ENV_CONFIG_MAPPING):
        """
        Automatically bind SENTRY_OPTIONS from a set of environment variables.
        """
        for env_var, item in six.iteritems(mapping):
            # HACK: we need to check both in `os.environ` and `env._cache`.
            # This is very much an implementation detail leaking out
            # due to assumptions about how `env` would be used previously.
            # `env` will pop values out of `os.environ` when they are seen,
            # so checking against `os.environ` only means it's likely
            # they won't exist if `env()` has been called on the variable
            # before at any point. So we're choosing to check both, but this
            # behavior is different since we're trying to only conditionally
            # apply variables, instead of setting them always.
            if env_var not in os.environ and env_var not in env._cache:
                continue
            if isinstance(item, tuple):
                opt_key, type_ = item
            else:
                opt_key, type_ = item, None
            config[opt_key] = env(env_var, type=type_)

    # If this value ever becomes compromised, it's important to regenerate your
    # SENTRY_SECRET_KEY. Changing this value will result in all current sessions
    # being invalidated.
    secret_key = env('SENTRY_SECRET_KEY')
    if not secret_key:
        raise Exception('Error: SENTRY_SECRET_KEY is undefined, run `generate-secret-key` and set to -e SENTRY_SECRET_KEY')

    if 'SENTRY_RUNNING_UWSGI' not in os.environ and len(secret_key) < 32:
        print('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!')
        print('!!                    CAUTION                       !!')
        print('!! Your SENTRY_SECRET_KEY is potentially insecure.  !!')
        print('!!    We recommend at least 32 characters long.     !!')
        print('!!     Regenerate with `generate-secret-key`.       !!')
        print('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!')

    # Grab the easy configuration first - these are all fixed
    # key=value with no logic behind them
    bind_env_config()

    # If you specify a MAILGUN_API_KEY, you definitely want EMAIL_REPLIES
    if SENTRY_OPTIONS.get('mail.mailgun-api-key'):
        SENTRY_OPTIONS.setdefault('mail.enable-replies', True)

    if 'GITHUB_APP_ID' in os.environ:
        GITHUB_EXTENDED_PERMISSIONS = ['repo']
        GITHUB_APP_ID = env('GITHUB_APP_ID')
        GITHUB_API_SECRET = env('GITHUB_API_SECRET')

    if 'BITBUCKET_CONSUMER_KEY' in os.environ:
        BITBUCKET_CONSUMER_KEY = env('BITBUCKET_CONSUMER_KEY')
        BITBUCKET_CONSUMER_SECRET = env('BITBUCKET_CONSUMER_SECRET')
---
# Source: sentry/templates/pvc.yaml
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: ak-sentry
  labels:
    app: ak-sentry
    chart: "sentry-4.3.3"
    release: "ak"
    heritage: "Helm"
spec:
  accessModes:
    - "ReadWriteOnce"
  storageClassName: nfs  #根据实际修改
  resources:
    requests:
      storage: "10Gi"
---
# Source: sentry/charts/postgresql/templates/svc-headless.yaml
apiVersion: v1
kind: Service
metadata:
  name: ak-sentry-postgresql-headless
  labels:
    app: sentry-postgresql
    chart: postgresql-6.5.0
    release: "ak"
    heritage: "Helm"
spec:
  type: ClusterIP
  clusterIP: None
  ports:
  - name: postgresql
    port: 5432
    targetPort: postgresql
  selector:
    app: sentry-postgresql
    release: "ak"
---
# Source: sentry/charts/postgresql/templates/svc.yaml
apiVersion: v1
kind: Service
metadata:
  name: ak-sentry-postgresql
  labels:
    app: sentry-postgresql
    chart: postgresql-6.5.0
    release: "ak"
    heritage: "Helm"
spec:
  type: ClusterIP
  ports:
  - name: postgresql
    port: 5432
    targetPort: postgresql
  selector:
    app: sentry-postgresql
    release: "ak"
    role: master
---
# Source: sentry/charts/redis/templates/headless-svc.yaml
apiVersion: v1
kind: Service
metadata:
  name: ak-sentry-redis-headless
  labels:
    app: sentry-redis
    chart: redis-9.3.2
    release: ak
    heritage: Helm
spec:
  type: ClusterIP
  clusterIP: None
  ports:
  - name: redis
    port: 6379
    targetPort: redis
  selector:
    app: sentry-redis
    release: ak
---
# Source: sentry/charts/redis/templates/redis-master-svc.yaml
apiVersion: v1
kind: Service
metadata:
  name: ak-sentry-redis-master
  labels:
    app: sentry-redis
    chart: redis-9.3.2
    release: ak
    heritage: Helm
spec:
  type: ClusterIP
  ports:
  - name: redis
    port: 6379
    targetPort: redis
  selector:
    app: sentry-redis
    release: ak
    role: master
---
# Source: sentry/charts/redis/templates/redis-slave-svc.yaml
apiVersion: v1
kind: Service
metadata:
  name: ak-sentry-redis-slave
  labels:
    app: sentry-redis
    chart: redis-9.3.2
    release: ak
    heritage: Helm
spec:
  type: ClusterIP
  ports:
  - name: redis
    port: 6379
    targetPort: redis
  selector:
    app: sentry-redis
    release: ak
    role: slave
---
# Source: sentry/templates/web-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: ak-sentry
  annotations:
  labels:
    app: ak-sentry
    chart: "sentry-4.3.3"
    release: "ak"
    heritage: "Helm"
spec:
  type: NodePort
  ports:
  - port: 9000
    targetPort: 9000
    protocol: TCP
    name: sentry
    nodePort: 32655
  selector:
    app: ak-sentry
    role: web
---
# Source: sentry/templates/cron-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ak-sentry-cron
  labels:
    app: ak-sentry
    chart: "sentry-4.3.3"
    release: "ak"
    heritage: "Helm"
spec:
  selector:
    matchLabels:
        app: ak-sentry
        release: "ak"
        role: cron
  replicas: 1
  template:
    metadata:
      annotations:
        metrics-enabled: "false"
        checksum/configYml: e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
        checksum/sentryConfPy: e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
        checksum/secrets.yaml: 5d08f05eb3b74a7225b6c27da9a51409a23e64d0d27a6fc9511853f0859aa79d
      labels:
        app: ak-sentry
        release: "ak"
        role: cron
    spec:
      serviceAccountName: ak-sentry
      containers:
      - name: sentry-cron
        image: "sentry:9.1.2"
        imagePullPolicy: IfNotPresent
        args: ["run", "cron"]
        ports:
        - containerPort: 9000
        env:
        - name: SENTRY_SECRET_KEY
          valueFrom:
            secretKeyRef:
              name: ak-sentry
              key: sentry-secret
        - name: SENTRY_DB_USER
          value: "postgres"
        - name: SENTRY_DB_NAME
          value: "sentry"
        - name: SENTRY_DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: ak-sentry-postgresql
              key: "postgresql-password"
        - name: SENTRY_POSTGRES_HOST
          value: ak-sentry-postgresql
        - name: SENTRY_POSTGRES_PORT
          value: "5432"
        - name: SENTRY_REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: ak-sentry-redis
              key: "redis-password"
        - name: SENTRY_REDIS_HOST
          value: ak-sentry-redis-master
        - name: SENTRY_REDIS_PORT
          value: "6379"
        - name: SENTRY_EMAIL_HOST
          value: "smtp"
        - name: SENTRY_EMAIL_PORT
          value: "25"
        - name: SENTRY_EMAIL_USER
          value: ""
        - name: SENTRY_EMAIL_PASSWORD
          valueFrom:
            secretKeyRef:
              name: ak-sentry
              key: smtp-password
        - name: SENTRY_EMAIL_USE_TLS
          value: "false"
        - name: SENTRY_SERVER_EMAIL
          value: "sentry@sentry.local"
        volumeMounts:
        - mountPath: /etc/sentry
          name: config
          readOnly: true
        - mountPath: /var/lib/sentry/files
          name: sentry-data
        resources:
            {}
      volumes:
      - name: config
        configMap:
          name: ak-sentry
      - name: sentry-data
        emptyDir: {}
---
# Source: sentry/templates/web-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ak-sentry-web
  labels:
    app: ak-sentry
    chart: "sentry-4.3.3"
    release: "ak"
    heritage: "Helm"
spec:
  selector:
    matchLabels:
        app: ak-sentry
        release: "ak"
        role: web
  replicas: 1
  template:
    metadata:
      annotations:
        metrics-enabled: "false"
        checksum/configYml: e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
        checksum/sentryConfPy: e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
        checksum/secrets.yaml: f5c223f26a758a4b4c13444991be9266d9bc207f6c21f6ba485409bf842f8a11
      labels:
        app: ak-sentry
        release: "ak"
        role: web
    spec:
      serviceAccountName: ak-sentry
      containers:
      - name: sentry-web
        image: "sentry:9.1.2"
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 9000
        env:
        - name: SENTRY_SECRET_KEY
          valueFrom:
            secretKeyRef:
              name: ak-sentry
              key: sentry-secret
        - name: SENTRY_DB_USER
          value: "postgres"
        - name: SENTRY_DB_NAME
          value: "sentry"
        - name: SENTRY_DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: ak-sentry-postgresql
              key: "postgresql-password"
        - name: SENTRY_POSTGRES_HOST
          value: ak-sentry-postgresql
        - name: SENTRY_POSTGRES_PORT
          value: "5432"
        - name: SENTRY_REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: ak-sentry-redis
              key: "redis-password"
        - name: SENTRY_REDIS_HOST
          value: ak-sentry-redis-master
        - name: SENTRY_REDIS_PORT
          value: "6379"
        - name: SENTRY_EMAIL_HOST
          value: "smtp"
        - name: SENTRY_EMAIL_PORT
          value: "25"
        - name: SENTRY_EMAIL_USER
          value: "sentry@sentry.local"
        - name: SENTRY_EMAIL_PASSWORD
          valueFrom:
            secretKeyRef:
              name: ak-sentry
              key: smtp-password
        - name: SENTRY_EMAIL_USE_TLS
          value: "false"
        - name: SENTRY_SERVER_EMAIL
          value: "sentry@sentry.local"
        
        - name: GITHUB_APP_ID
          value: null
        - name: GITHUB_API_SECRET
          value: null
        volumeMounts:
        - mountPath: /etc/sentry
          name: config
          readOnly: true
        - mountPath: /var/lib/sentry/files
          name: sentry-data
        livenessProbe:
          failureThreshold: 5
          httpGet:
            path: /_health/
            port: 9000
            scheme: HTTP
          initialDelaySeconds: 50
          periodSeconds: 10
          successThreshold: 1
          timeoutSeconds: 2
        readinessProbe:
          failureThreshold: 10
          httpGet:
            path: /_health/
            port: 9000
            scheme: HTTP
          initialDelaySeconds: 50
          periodSeconds: 10
          successThreshold: 1
          timeoutSeconds: 2
        resources:
            {}
      volumes:
      - name: config
        configMap:
          name: ak-sentry
      - name: sentry-data
        persistentVolumeClaim:
          claimName: ak-sentry
---
# Source: sentry/templates/workers-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ak-sentry-worker
  labels:
    app: ak-sentry
    chart: "sentry-4.3.3"
    release: "ak"
    heritage: "Helm"
spec:
  selector:
    matchLabels:
        app: ak-sentry
        release: "ak"
        role: worker
  replicas: 2
  template:
    metadata:
      annotations:
        metrics-enabled: "false"
        checksum/configYml: e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
        checksum/sentryConfPy: e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
        checksum/secrets.yaml: 9f1593623c6291cdf6002e0efa079cc474853f609cadb625f8c2306296f2e89c
      labels:
        app: ak-sentry
        release: "ak"
        role: worker
    spec:
      serviceAccountName: ak-sentry
      containers:
      - name: sentry-workers
        image: "sentry:9.1.2"
        imagePullPolicy: IfNotPresent
        args:
          - "run"
          - "worker"
        ports:
        - containerPort: 9000
        env:
        - name: SENTRY_SECRET_KEY
          valueFrom:
            secretKeyRef:
              name: ak-sentry
              key: sentry-secret
        - name: SENTRY_DB_USER
          value: "postgres"
        - name: SENTRY_DB_NAME
          value: "sentry"
        - name: SENTRY_DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: ak-sentry-postgresql
              key: "postgresql-password"
        - name: SENTRY_POSTGRES_HOST
          value: ak-sentry-postgresql
        - name: SENTRY_POSTGRES_PORT
          value: "5432"
        - name: SENTRY_REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: ak-sentry-redis
              key: "redis-password"
        - name: SENTRY_REDIS_HOST
          value: ak-sentry-redis-master
        - name: SENTRY_REDIS_PORT
          value: "6379"
        - name: SENTRY_EMAIL_HOST
          value: "smtp"
        - name: SENTRY_EMAIL_PORT
          value: "25"
        - name: SENTRY_EMAIL_USER
          value: ""
        - name: SENTRY_EMAIL_PASSWORD
          valueFrom:
            secretKeyRef:
              name: ak-sentry
              key: smtp-password
        - name: SENTRY_EMAIL_USE_TLS
          value: "false"
        - name: SENTRY_SERVER_EMAIL
          value: "sentry@sentry.local"
        
        volumeMounts:
        - mountPath: /etc/sentry
          name: config
          readOnly: true
        - mountPath: /var/lib/sentry/files
          name: sentry-data
        resources:
            {}
      volumes:
      - name: config
        configMap:
          name: ak-sentry
      - name: sentry-data
        emptyDir: {}
---
# Source: sentry/charts/postgresql/templates/statefulset.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: ak-sentry-postgresql
  labels:
    app: sentry-postgresql
    chart: postgresql-6.5.0
    release: "ak"
    heritage: "Helm"
spec:
  serviceName: ak-sentry-postgresql-headless
  replicas: 1
  updateStrategy:
    type: RollingUpdate
  selector:
    matchLabels:
      app: sentry-postgresql
      release: "ak"
      role: master
  template:
    metadata:
      name: ak-sentry-postgresql
      labels:
        app: sentry-postgresql
        chart: postgresql-6.5.0
        release: "ak"
        heritage: "Helm"
        role: master
    spec:      
      securityContext:
        fsGroup: 1001
      initContainers:
      - name: init-chmod-data
        image: docker.io/bitnami/minideb:stretch
        imagePullPolicy: "Always"
        resources:
          requests:
            cpu: 250m
            memory: 256Mi
        command:
          - sh
          - -c
          - |
            mkdir -p /bitnami/postgresql/data
            chmod 700 /bitnami/postgresql/data
            find /bitnami/postgresql -mindepth 0 -maxdepth 1 -not -name ".snapshot" -not -name "lost+found" | \
              xargs chown -R 1001:1001
        securityContext:
          runAsUser: 0
        volumeMounts:
        - name: data
          mountPath: /bitnami/postgresql
          subPath: 
      containers:
      - name: ak-sentry-postgresql
        image: docker.io/bitnami/postgresql:11.5.0-debian-9-r60
        imagePullPolicy: "IfNotPresent"
        resources:
          requests:
            cpu: 250m
            memory: 256Mi
        securityContext:
          runAsUser: 1001
        env:
        - name: BITNAMI_DEBUG
          value: "false"
        - name: POSTGRESQL_PORT_NUMBER
          value: "5432"
        - name: POSTGRESQL_VOLUME_DIR
          value: "/bitnami/postgresql"
        - name: PGDATA
          value: "/bitnami/postgresql/data"
        - name: POSTGRES_USER
          value: "postgres"
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: ak-sentry-postgresql
              key: postgresql-password
        - name: POSTGRES_DB
          value: "sentry"
        ports:
        - name: postgresql
          containerPort: 5432
        livenessProbe:
          exec:
            command:
            - sh
            - -c
            - exec pg_isready -U "postgres" -d "sentry" -h 127.0.0.1 -p 5432
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          successThreshold: 1
          failureThreshold: 6
        readinessProbe:
          exec:
            command:
            - sh
            - -c
            - -e
            - |
              pg_isready -U "postgres" -d "sentry" -h 127.0.0.1 -p 5432
              [ -f /opt/bitnami/postgresql/tmp/.initialized ]
          initialDelaySeconds: 5
          periodSeconds: 10
          timeoutSeconds: 5
          successThreshold: 1
          failureThreshold: 6
        volumeMounts:
        - name: data
          mountPath: /bitnami/postgresql
          subPath: 
      #volumes:
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes:
          - "ReadWriteOnce"
        storageClassName: cbs
        resources:
          requests:
            storage: "10Gi"
---
# Source: sentry/charts/redis/templates/redis-master-statefulset.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: ak-sentry-redis-master
  labels:
    app: sentry-redis
    chart: redis-9.3.2
    release: ak
    heritage: Helm
spec:
  selector:
    matchLabels:
      app: sentry-redis
      release: ak
      role: master
  serviceName: ak-sentry-redis-headless
  template:
    metadata:
      labels:
        app: sentry-redis
        chart: redis-9.3.2
        release: ak
        role: master
      annotations:
        checksum/health: 25adbdb188138202ef56260224d0a2352d2c6374940d0ee828cbd0088398d887
        checksum/configmap: 9af59df6909d9363547c86290787ba12ff6ebf24c2027919225c0b5356446145
        checksum/secret: 834bdc7cde3223dd2f93fe84dd72bb64b69ab45c3c982180df459c87f581c283
    spec:      
      securityContext:
        fsGroup: 1001
      serviceAccountName: "default"
      containers:
      - name: ak-sentry-redis
        image: "docker.io/bitnami/redis:5.0.5-debian-9-r141"
        imagePullPolicy: "IfNotPresent"
        securityContext:
          runAsUser: 1001
        command:
        - /bin/bash
        - -c
        - |
          if [[ -n $REDIS_PASSWORD_FILE ]]; then
            password_aux=`cat ${REDIS_PASSWORD_FILE}`
            export REDIS_PASSWORD=$password_aux
          fi
          if [[ ! -f /opt/bitnami/redis/etc/master.conf ]];then
            cp /opt/bitnami/redis/mounted-etc/master.conf /opt/bitnami/redis/etc/master.conf
          fi
          if [[ ! -f /opt/bitnami/redis/etc/redis.conf ]];then
            cp /opt/bitnami/redis/mounted-etc/redis.conf /opt/bitnami/redis/etc/redis.conf
          fi
          ARGS=("--port" "${REDIS_PORT}")
          ARGS+=("--requirepass" "${REDIS_PASSWORD}")
          ARGS+=("--masterauth" "${REDIS_PASSWORD}")
          ARGS+=("--include" "/opt/bitnami/redis/etc/redis.conf")
          ARGS+=("--include" "/opt/bitnami/redis/etc/master.conf")
          /run.sh ${ARGS[@]}
        env:
        - name: REDIS_REPLICATION_MODE
          value: master
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: ak-sentry-redis
              key: redis-password
        - name: REDIS_PORT
          value: "6379"
        ports:
        - name: redis
          containerPort: 6379
        livenessProbe:
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 5
          successThreshold: 1
          failureThreshold: 5
          exec:
            command:
            - sh
            - -c
            - /health/ping_liveness_local.sh 5
        readinessProbe:
          initialDelaySeconds: 5
          periodSeconds: 5
          timeoutSeconds: 1
          successThreshold: 1
          failureThreshold: 5
          exec:
            command:
            - sh
            - -c
            - /health/ping_readiness_local.sh 5
        resources:
          null
        volumeMounts:
        - name: health
          mountPath: /health
        - name: redis-data
          mountPath: /data
          subPath: 
        - name: config
          mountPath: /opt/bitnami/redis/mounted-etc
        - name: redis-tmp-conf
          mountPath: /opt/bitnami/redis/etc/
      volumes:
      - name: health
        configMap:
          name: ak-sentry-redis-health
          defaultMode: 0755
      - name: config
        configMap:
          name: ak-sentry-redis
      - name: redis-tmp-conf
        emptyDir: {}
  volumeClaimTemplates:
    - metadata:
        name: redis-data
        labels:
          app: sentry-redis
          release: ak
          heritage: Helm
          component: master
      spec:
        accessModes:
          - "ReadWriteOnce"
        storageClassName: cbs
        resources:
          requests:
            storage: "10Gi"
        
  updateStrategy:
    type: RollingUpdate
---
# Source: sentry/charts/redis/templates/redis-slave-statefulset.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: ak-sentry-redis-slave
  labels:
    app: sentry-redis
    chart: redis-9.3.2
    release: ak
    heritage: Helm
spec:
  replicas: 2
  serviceName: ak-sentry-redis-headless
  selector:
    matchLabels:
      app: sentry-redis
      release: ak
      role: slave
  template:
    metadata:
      labels:
        app: sentry-redis
        release: ak
        chart: redis-9.3.2
        role: slave
      annotations:
        checksum/health: 25adbdb188138202ef56260224d0a2352d2c6374940d0ee828cbd0088398d887
        checksum/configmap: 9af59df6909d9363547c86290787ba12ff6ebf24c2027919225c0b5356446145
        checksum/secret: 8b05f297edc6b820fc02c95bdae89f8c4989f7e259a38b346a133bb0e05bfd96
    spec:      
      securityContext:
        fsGroup: 1001
      serviceAccountName: "default"
      containers:
      - name: ak-sentry-redis
        image: docker.io/bitnami/redis:5.0.5-debian-9-r141
        imagePullPolicy: "IfNotPresent"
        securityContext:
          runAsUser: 1001
        command:
        - /bin/bash
        - -c
        - |
          if [[ -n $REDIS_PASSWORD_FILE ]]; then
            password_aux=`cat ${REDIS_PASSWORD_FILE}`
            export REDIS_PASSWORD=$password_aux
          fi
          if [[ -n $REDIS_MASTER_PASSWORD_FILE ]]; then
            password_aux=`cat ${REDIS_MASTER_PASSWORD_FILE}`
            export REDIS_MASTER_PASSWORD=$password_aux
          fi
          if [[ ! -f /opt/bitnami/redis/etc/replica.conf ]];then
            cp /opt/bitnami/redis/mounted-etc/replica.conf /opt/bitnami/redis/etc/replica.conf
          fi
          if [[ ! -f /opt/bitnami/redis/etc/redis.conf ]];then
            cp /opt/bitnami/redis/mounted-etc/redis.conf /opt/bitnami/redis/etc/redis.conf
          fi
          ARGS=("--port" "${REDIS_PORT}")
          ARGS+=("--slaveof" "${REDIS_MASTER_HOST}" "${REDIS_MASTER_PORT_NUMBER}")
          ARGS+=("--requirepass" "${REDIS_PASSWORD}")
          ARGS+=("--masterauth" "${REDIS_MASTER_PASSWORD}")
          ARGS+=("--include" "/opt/bitnami/redis/etc/redis.conf")
          ARGS+=("--include" "/opt/bitnami/redis/etc/replica.conf")
          /run.sh "${ARGS[@]}"
        env:
        - name: REDIS_REPLICATION_MODE
          value: slave
        - name: REDIS_MASTER_HOST
          value: ak-sentry-redis-master-0.ak-sentry-redis-headless.sentry.svc.cluster.local
        - name: REDIS_PORT
          value: "6379"
        - name: REDIS_MASTER_PORT_NUMBER
          value: "6379"
        - name: REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: ak-sentry-redis
              key: redis-password
        - name: REDIS_MASTER_PASSWORD
          valueFrom:
            secretKeyRef:
              name: ak-sentry-redis
              key: redis-password
        ports:
        - name: redis
          containerPort: 6379
        livenessProbe:
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          successThreshold: 1
          failureThreshold: 5
          exec:
            command:
            - sh
            - -c
            - /health/ping_liveness_local_and_master.sh 5
        readinessProbe:
          initialDelaySeconds: 5
          periodSeconds: 10
          timeoutSeconds: 10
          successThreshold: 1
          failureThreshold: 5
          exec:
            command:
            - sh
            - -c
            - /health/ping_readiness_local_and_master.sh 5
        resources:
          null
        volumeMounts:
        - name: health
          mountPath: /health
        - name: redis-data
          mountPath: /data
        - name: config
          mountPath: /opt/bitnami/redis/mounted-etc
        - name: redis-tmp-conf
          mountPath: /opt/bitnami/redis/etc
      volumes:
      - name: health
        configMap:
          name: ak-sentry-redis-health
          defaultMode: 0755
      - name: config
        configMap:
          name: ak-sentry-redis
      - name: sentinel-tmp-conf
        emptyDir: {}
      - name: redis-tmp-conf
        emptyDir: {}
  volumeClaimTemplates:
    - metadata:
        name: redis-data
        labels:
          app: sentry-redis
          release: ak
          heritage: Helm
          component: slave
      spec:
        accessModes:
          - "ReadWriteOnce"
        storageClassName: cbs
        resources:
          requests:
            storage: "10Gi"
        
  updateStrategy:
    type: RollingUpdate
---
# Source: sentry/templates/hooks/db-init.job.yaml
# https://docs.sentry.io/server/installation/docker/#running-migrations
apiVersion: batch/v1
kind: Job
metadata:
  name: "ak-db-init"
  labels:
    app: ak-sentry
    chart: "sentry-4.3.3"
    release: "ak"
    heritage: "Helm"
  annotations:
    # This is what defines this resource as a hook. Without this line, the
    # job is considered part of the release.
    "helm.sh/hook": "post-install,post-upgrade"
    "helm.sh/hook-delete-policy": "hook-succeeded,before-hook-creation"
    "helm.sh/hook-weight": "-5"
spec:
  template:
    metadata:
      name: "ak-db-init"
      annotations:
        checksum/secrets.yaml: b659a1aeab9b92a7c07a55e0a94648e7e8f98eb37c0ab25219831842f9e497a6
      labels:
        app: ak-sentry
        release: "ak"
    spec:
      restartPolicy: Never
      containers:
      - name: db-init-job
        image: "sentry:9.1.2"
        command: ["sentry","upgrade","--noinput"]
        env:
        - name: SENTRY_SECRET_KEY
          valueFrom:
            secretKeyRef:
              name: ak-sentry
              key: sentry-secret
        - name: SENTRY_DB_USER
          value: "postgres"
        - name: SENTRY_DB_NAME
          value: "sentry"
        - name: SENTRY_DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: ak-sentry-postgresql
              key: "postgresql-password"
        - name: SENTRY_POSTGRES_HOST
          value: ak-sentry-postgresql
        - name: SENTRY_POSTGRES_PORT
          value: "5432"
        - name: SENTRY_REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: ak-sentry-redis
              key: "redis-password"
        - name: SENTRY_REDIS_HOST
          value: ak-sentry-redis-master
        - name: SENTRY_REDIS_PORT
          value: "6379"
        - name: SENTRY_EMAIL_HOST
          value: "smtp"
        - name: SENTRY_EMAIL_PORT
          value: "25"
        - name: SENTRY_EMAIL_USER
          value: ""
        - name: SENTRY_EMAIL_PASSWORD
          valueFrom:
            secretKeyRef:
              name: ak-sentry
              key: smtp-password
        - name: SENTRY_EMAIL_USE_TLS
          value: "false"
        - name: SENTRY_SERVER_EMAIL
          value: "sentry@sentry.local"
        volumeMounts:
        - mountPath: /etc/sentry
          name: config
          readOnly: true
        resources:
          limits:
            memory: 3200Mi
          requests:
            memory: 3000Mi
      volumes:
      - name: config
        configMap:
          name: ak-sentry
---
# Source: sentry/templates/hooks/user-create.job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: "ak-user-create"
  labels:
    app: ak-sentry
    chart: "sentry-4.3.3"
    release: "ak"
    heritage: "Helm"
  annotations:
    # This is what defines this resource as a hook. Without this line, the
    # job is considered part of the release.
    "helm.sh/hook": post-install
    "helm.sh/hook-delete-policy": "hook-succeeded,before-hook-creation"
    "helm.sh/hook-weight": "5"
spec:
  template:
    metadata:
      name: "ak-user-create"
      annotations:
        checksum/secrets.yaml: 541794d16c3eae2b2ce076c7d8a68836c03d8b3d52fb4ef4b255e2a2bc5e031f
      labels:
        app: ak-sentry
        release: "ak"
    spec:
      restartPolicy: Never
      containers:
      - name: user-create-job
        image: "sentry:9.1.2"
        command: ["/bin/bash"]
        args:
          - "-c"
          - "export output=$(sentry createuser --no-input --email admin --superuser --password $SENTRY_USER_PASSWORD) || if echo $output | grep -q 'already exists'; then exit 0; else exit 1; fi"
        env:
        - name: SENTRY_SECRET_KEY
          valueFrom:
            secretKeyRef:
              name: ak-sentry
              key: sentry-secret
        - name: SENTRY_DB_USER
          value: "postgres"
        - name: SENTRY_DB_NAME
          value: "sentry"
        - name: SENTRY_DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: ak-sentry-postgresql
              key: "postgresql-password"
        - name: SENTRY_POSTGRES_HOST
          value: ak-sentry-postgresql
        - name: SENTRY_POSTGRES_PORT
          value: "5432"
        - name: SENTRY_REDIS_PASSWORD
          valueFrom:
            secretKeyRef:
              name: ak-sentry-redis
              key: "redis-password"
        - name: SENTRY_REDIS_HOST
          value: ak-sentry-redis-master
        - name: SENTRY_REDIS_PORT
          value: "6379"
        - name: SENTRY_EMAIL_HOST
          value: ""
        - name: SENTRY_EMAIL_PORT
          value: ""
        - name: SENTRY_EMAIL_USER
          value: ""
        - name: SENTRY_EMAIL_PASSWORD
          valueFrom:
            secretKeyRef:
              name: ak-sentry
              key: smtp-password
        - name: SENTRY_USER_PASSWORD
          valueFrom:
            secretKeyRef:
              name: ak-sentry
              key: user-password
        - name: SENTRY_EMAIL_USE_TLS
          value: "false"
        - name: SENTRY_SERVER_EMAIL
          value: "sentry@sentry.local"
        volumeMounts:
        - mountPath: /etc/sentry
          name: config
          readOnly: true
      volumes:
      - name: config
        configMap:
          name: ak-sentry
```

## 2.部署sentry

```shell
kubectl apply -f sentry.yaml -n sentry
```

## 3.初始化数据库

```shell
kubectl  exec -it -n sentry $(kubectl get pods  -n sentry  |grep sentry-web |awk '{print $1}') bash  sentry upgrade
```

## 4.创建用户

```shell
kubectl exec -it -n sentry $(kubectl get pods  -n sentry  |grep sentry-web |awk '{print $1}') bash sentry createuser
```

