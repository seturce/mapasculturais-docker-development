<?php
$config = include 'conf-base.php';

$site_name = 'Mapa Culturais';
$site_description = 'Mapa Cultural do Brasil';

/* Geolocalizacao centralizado no Ceara*/
$base_domain = @$_SERVER['HTTP_HOST'];
$base_url = 'http://' . $base_domain . '/';
$map_latitude = '-5.058114374355702';
$map_longitude = '-39.4134521484375' ;
$map_zoom = '7';

/* Timezone para Fortaleza/Ce */
date_default_timezone_set('America/Fortaleza');

return array_merge($config,
    [
        'app.siteName' => \MapasCulturais\i::__($site_name),
        'app.siteDescription' => \MapasCulturais\i::__($site_description),
        /* Habilitar configurações importantes da aplicação: [development, staging, production] */ 
        'app.mode' => 'development',         
        'app.enabled.seals'   => false,
        'app.enabled.apps'     => false,
        'app.offline' => false,
        'app.offlineUrl' => '/offline',
        'app.offlineBypassFunction' => null,
        'app.log.path' => '/var/log/nginx/',	   
        
        'api.accessControlAllowOrigin' => '*',

        'base.assetUrl' => $base_url . 'assets/',
        'base.url' => $base_url,                

        /* Doctrine configurations */
        'doctrine.isDev' => true,
        
        /* ==================== LOGS ================== */
        'slim.debug' => true,
        'slim.log.enabled' => true,
        'slim.log.level' => \Slim\Log::DEBUG,
        'slim.log.writer' => new \MapasCulturais\Loggers\File(function () {return 'slim.log'; }),


        /* Configurações do Mapa e GeoDivisão */
        'maps.includeGoogleLayers' => true,
        'maps.center' => array($map_latitude, $map_longitude),
        'maps.zoom.default' => $map_zoom,

        'app.geoDivisionsHierarchy' => [],

        'plugins.enabled' => ['agenda-singles', 'endereco', 'notifications', 'em-cartaz', 'mailer'],

        /* configuração do tempo das notificações */
        'notifications.entities.update' => 0,
        'notifications.user.access' => 0,

        /* configuração do serviço de e-mail */
        'mailer.user' => "",
        'mailer.psw'  => "",
        'mailer.server' => '',
        'mailer.protocol' => '',
        'mailer.port'   => '',
        'mailer.from' => '',

        'plugins' => array_merge ($config['plugins'],
            [
                'EvaluationMethodSimple' => ['namespace' => 'EvaluationMethodSimple'],
                'EvaluationMethodDocumentary' => ['namespace' => 'EvaluationMethodDocumentary'],
                'EvaluationMethodTechnical' => ['namespace' => 'EvaluationMethodTechnical']
            ]
        ),

        'auth.provider' => 'Fake',

        'doctrine.database' => [
            'dbname'    => 'mapasculturais',
            'user'      => 'postgres',
            'password'  => 'postgres',
            'host'      => 'mapas-postgresql',
            'port'      => '5432',
        ],
    ]
);
