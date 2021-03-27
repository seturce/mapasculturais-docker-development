<?php
$config = include 'conf-base.php';

$site_name = 'Mapa Cultural do Ceará';
$site_description = 'O Mapa Cultural do Ceará é a plataforma livre, gratuita e colaborativa de mapeamento da Secretaria da Cultura do Estado do Ceará sobre cenário cultural cearense. Ficou mais fácil se programar para conhecer as opções culturais que as cidades cearenses oferecem: shows musicais, espetáculos teatrais, sessões de cinema, saraus, entre outras. Além de conferir a agenda de eventos, você também pode colaborar na gestão da cultura do estado: basta criar seu perfil de agente cultural. A partir deste cadastro, fica mais fácil participar dos editais e programas da Secretaria e também divulgar seus eventos, espaços ou projetos.';

$base_domain = @$_SERVER['HTTP_HOST'];
$base_url = 'http://' . $base_domain . '/';
$map_latitude = '-5.058114374355702';
$map_longitude = '-39.4134521484375' ;
$map_zoom = '7';

date_default_timezone_set('America/Fortaleza');

return array_merge($config,
    [
        'app.useAssetsUrlCache' => 1,
        'app.siteName' => \MapasCulturais\i::__($site_name),
        'app.siteDescription' => \MapasCulturais\i::__($site_description),

        /* to setup Saas Subsite theme */
        'namespaces' => [
            'MapasCulturais\Themes' => THEMES_PATH,
            'Ceara' => THEMES_PATH . '/Ceara/',
            'Subsite' => THEMES_PATH . '/Subsite/'
        ],

        'themes.active' => 'Ceara',
        'base.assetUrl' => $base_url . 'assets/',
        'base.url' => $base_url,

        /* Habilitar configurações importantes da aplicação: [development, staging, production] */ 
        'app.mode' => 'development',
        'app.enabled.seals'   => true,
        'app.enabled.apps' => false,
        'api.accessControlAllowOrigin' => '*',
        'app.offline' => false,
        'app.offlineUrl' => '/offline',
        'app.offlineBypassFunction' => null,

        /* Doctrine configurations */
        'doctrine.isDev' => false,
        
        /* ==================== LOGS ================== */
        #'slim.debug' => false,
        #'slim.log.enabled' => true,
        #'slim.log.level' => \Slim\Log::DEBUG,
        #'app.log.hook' => true,
        #'app.log.query' => true,
        #'app.log.requestData' => true,
        #'app.log.translations' => true,
        #'app.log.apiCache' => true,
        #'app.log.path' => '/dados/mapas/logs/',
        #'slim.log.writer' => new \MapasCulturais\Loggers\File(function () {return 'slim.log'; }),


        /* Configurações do Mapa e GeoDivisão */
        'maps.includeGoogleLayers' => true,
        'maps.center' => array($map_latitude, $map_longitude),
        'maps.zoom.default' => $map_zoom,

        ## Plugins 
        'plugins.enabled' => array('agenda-singles', 'endereco', 'notifications', 'em-cartaz', 'mailer'),

        'mailer.user' => '1b40c2575af2e2',
        'mailer.psw'  => 'c0390d3c1d1369',
        'mailer.server' => 'smtp.mailtrap.io',
        'mailer.protocol' => 'tls',
        'mailer.port'   => '2525',
        'mailer.from' => 'naoresponda@secult.ce.gov.br',

        'plugins' => array_merge( $config['plugins'],
            [
                'MultipleLocalAuth' => ['namespace' => 'MultipleLocalAuth'],
		        'EvaluationMethodSimple' => ['namespace' => 'EvaluationMethodSimple'],
                'EvaluationMethodDocumentary' => ['namespace' => 'EvaluationMethodDocumentary'],
                'EvaluationMethodTechnical' => ['namespace' => 'EvaluationMethodTechnical'],
            ]
        ),
        /*	Esse módulo é para configurar a funcionalidade de denúncia e/ou sugestões */
        'module.CompliantSuggestion' => [
                'compliant' => false,
                'suggestion' => false
        ],

        // Token da API de Cep
        // Adquirido ao fazer cadastro em http://www.cepaberto.com/
        'cep.token' => '1a61e4d00bf9c6a85e3b696ef7014372',

        //'auth.provider' => 'Fake',
        /* configuração de provedores Auth para Login */
         'auth.provider' => '\MultipleLocalAuth\Provider',
         'auth.config' => [
             'salt' => 'LT_SECURITY_SALT_SECURITY_SALT_SECURITY_SALT_SECURITY_SALT_SECU',
             'timeout' => '24 hours',
             'enableLoginByCPF' => true,
             'metadataFieldCPF' => 'documento',
             'userMustConfirmEmailToUseTheSystem' => false,
             'passwordMustHaveCapitalLetters' => true,
             'passwordMustHaveLowercaseLetters' => true,
             'passwordMustHaveSpecialCharacters' => true,
             'passwordMustHaveNumbers' => true,
             'minimumPasswordLength' => 7,
             'google-recaptcha-secret' => '6LeIxAcTAAAAAGG-vFI1TnRWxMZNFuojJ4WifJWe',
             'google-recaptcha-sitekey' => '6LeIxAcTAAAAAJcZVRqyHh71UMIEGNQ_MXjiZKhI',
             'sessionTime' => 7200, // int , tempo da sessao do usuario em segundos
             'numberloginAttemp' => '5', // tentativas de login antes de bloquear o usuario por X minutos
             'timeBlockedloginAttemp' => '900', // tempo de bloqueio do usuario em segundos
             'strategies' => [],        
        ],

        'doctrine.database' => [
            'dbname'    => 'mapas',
            'user'      => 'mapas',
            'password'  => 'mapas',
            'host'      => 'mapas-postgresql',
            'port'      => '5432',
        ],
    ]
);

