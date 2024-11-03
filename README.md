# AWS - Inlämningsuppgift 2
### Skapa en Robust och Säker WordPress-Site med AWS EFS och RDS

Denna guide beskriver hur du bygger en robust och skalbar WordPress-miljö på AWS med Elastic File System (EFS) för filhantering och Relational Database Service (RDS) för databaslagring. Guiden bygger vidare från föregående uppgift och fokuserar på att skapa en miljö som är både robust och skalbar för WordPress.


### Förkrav

För att följa denna guide och skapa en robust, säker och skalbar hosting-miljö för WordPress, säkerställ att följande tjänster och applikationer är installerade och konfigurerade:

- **[Visual Studio Code](https://code.visualstudio.com/Download)**: Textredigerare för att hantera kod.
- **[Registrera ett AWS-konto](https://aws.amazon.com/free/)**: För att komma åt AWS-tjänster.
- **[AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)**: Kommandoradsverktyg för att interagera med AWS-tjänster (kan kräva installation av **[Python](https://www.python.org/downloads/)** för att fungera korrekt).

Notera att **AWS CLI** kan kräva installation av **Python** för att fungera beroende på ditt operativsystem och den version av CLI du använder.

### Verifiera installationen av AWS CLI

För att kontrollera att AWS CLI har installerats korrekt, kan du köra följande kommando i terminalen:

```bash
aws --version
```

# Innehållsförteckning
- [Skapa en VPC för host-miljön](#skapa-en-vpc-för-host-miljön)
- [Skapa Säkerhetsgrupper](#skapa-säkerhetsgrupper)
- [Skapa EFS för WordPress miljön](#skapa-elastic-file-system-efs)
- [Skapa Application Load Balancer för miljön](#skapa-application-load-balancer-alb)
- [Skapa RDS som WordPress-databas](#skapa-amazon-rds-för-wordpress)
- [Skapa provisionerings server för miljön](#provisioning-server-för-wordpress)
- [Skapa LaunchTemplate för LAMP-instanser](#launch-template)
- [Skapa Auto Scaling Group för miljön](#auto-scaling-group)
- [Skapa Admin server för miljön](#adminserver)
- [Skapa deploy skript](#deploy-skript-för-wordpress-miljö)
- [Radera stack för labb-miljö](#radera-stack-vid-labb)



## Skapa en VPC för host-miljön

Det vi ska börja med är att skapa en ny VPC för vår hosting-miljö. En VPC (Virtual Private Cloud) ger en isolerad miljö där du kan köra dina resurser i AWS. Genom att definiera en VPC kan du styra nätverkskonfigurationer, inklusive IP-adressering, subnät, routing och säkerhet. 

I denna VPC kommer vi att skapa följande komponenter:

- **Internet Gateway**: Gör att resurser i VPC:n kan kommunicera med internet.
- **VPC Gateway Attachment**: Kopplar Internet Gateway till vår VPC.
- **Routing Tables**: Definierar hur trafik ska dirigeras inom VPC:n, inklusive separata tabeller för offentliga och privata subnät.
- **Public Subnets**: Tre offentliga subnät som gör det möjligt för resurser att nås från internet.
- **Private Subnets**: Tre privata subnät, ett i varje tillgänglighetszon, för att skydda interna resurser.
- **Subnet Route Table Associations**: Kopplar subnät till rätt routetabeller för att säkerställa korrekt trafikdirigering.

Lägg till följande kod under Resources: i din Cloudformation.yaml-fil

```yaml
Resources:
  # Create VPC
  VPC:
    Type: AWS::EC2::VPC
    Properties:
      CidrBlock: 10.0.0.0/16
      EnableDnsSupport: true
      EnableDnsHostnames: true
      Tags:
        - Key: Name
          Value: VPC

  # Create Internet Gateway
  InternetGateway:
    Type: AWS::EC2::InternetGateway
    Properties:
      Tags:
        - Key: Name
          Value: InternetGateway

  # Attach Internet Gateway to VPC
  AttachGateway:
    Type: AWS::EC2::VPCGatewayAttachment
    Properties:
      VpcId: !Ref VPC
      InternetGatewayId: !Ref InternetGateway

  # Create Public Route Table
  PublicRouteTable:
    Type: AWS::EC2::RouteTable
    Properties:
      VpcId: !Ref VPC
      Tags:
        - Key: Name
          Value: PublicRouteTable

  # Create Route to Internet for Public Route Table
  PublicRoute:
    Type: AWS::EC2::Route
    Properties:
      RouteTableId: !Ref PublicRouteTable
      DestinationCidrBlock: 0.0.0.0/0
      GatewayId: !Ref InternetGateway

  # Create Public Subnets
  PublicSubnetA:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      CidrBlock: 10.0.1.0/24
      AvailabilityZone: eu-west-1a
      MapPublicIpOnLaunch: true
      Tags:
        - Key: Name
          Value: PublicSubnetA

  PublicSubnetB:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      CidrBlock: 10.0.2.0/24
      AvailabilityZone: eu-west-1b
      MapPublicIpOnLaunch: true
      Tags:
        - Key: Name
          Value: PublicSubnetB

  PublicSubnetC:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      CidrBlock: 10.0.3.0/24
      AvailabilityZone: eu-west-1c
      MapPublicIpOnLaunch: true
      Tags:
        - Key: Name
          Value: PublicSubnetC

  # Associate Public Route Table with Public Subnets
  PublicSubnetARouteTableAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      SubnetId: !Ref PublicSubnetA
      RouteTableId: !Ref PublicRouteTable

  PublicSubnetBRouteTableAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      SubnetId: !Ref PublicSubnetB
      RouteTableId: !Ref PublicRouteTable

  PublicSubnetCRouteTableAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      SubnetId: !Ref PublicSubnetC
      RouteTableId: !Ref PublicRouteTable

  # Create Private Route Table
  PrivateRouteTable:
    Type: AWS::EC2::RouteTable
    Properties:
      VpcId: !Ref VPC
      Tags:
        - Key: Name
          Value: PrivateRouteTable

  # Create Private Subnets
  PrivateSubnetA:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      CidrBlock: 10.0.4.0/24
      AvailabilityZone: eu-west-1a
      MapPublicIpOnLaunch: false
      Tags:
        - Key: Name
          Value: PrivateSubnetA

  PrivateSubnetB:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      CidrBlock: 10.0.5.0/24
      AvailabilityZone: eu-west-1b
      MapPublicIpOnLaunch: false
      Tags:
        - Key: Name
          Value: PrivateSubnetB

  PrivateSubnetC:
    Type: AWS::EC2::Subnet
    Properties:
      VpcId: !Ref VPC
      CidrBlock: 10.0.6.0/24
      AvailabilityZone: eu-west-1c
      MapPublicIpOnLaunch: false
      Tags:
        - Key: Name
          Value: PrivateSubnetC

  # Associate Private Route Table with Private Subnets
  PrivateSubnetA  RouteTableAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      SubnetId: !Ref PrivateSubnetA
      RouteTableId: !Ref PrivateRouteTable

  PrivateSubnetBRouteTableAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      SubnetId: !Ref PrivateSubnetB
      RouteTableId: !Ref PrivateRouteTable

  PrivateSubnetCRouteTableAssociation:
    Type: AWS::EC2::SubnetRouteTableAssociation
    Properties:
      SubnetId: !Ref PrivateSubnetC
      RouteTableId: !Ref PrivateRouteTable
```
[⬆️ Till toppen](#top)

## Skapa säkerhetsgrupper

För att säkerställa att vår WordPress-miljö fungerar korrekt behöver vi skapa säkerhetsgrupper. Dessa grupper kommer att ge de olika resurserna i vår miljö rätt behörigheter för att kommunicera med varandra och med externa användare. 

Säkerhetsgrupperna som vi kommer att definiera inkluderar:

### Parameters
- **AdminIP**: En parameter som anger den IP-adress som tillåts SSH-åtkomst till provisioning-servern. Standardvärdet är `0.0.0.0/0`, vilket innebär att alla IP-adresser är tillåtna, men detta bör begränsas i en produktionsmiljö.

### Resources
1. **SecurityGroupALB**: 
   - Typ: `AWS::EC2::SecurityGroup`
   - Beskrivning: Tillåter HTTP (port 80) och HTTPS (port 443) trafik till Application Load Balancer (ALB).
   - Ingress-regler: 
     - Tillåter inkommande trafik på TCP-port 80 och 443 från alla IP-adresser.

2. **SecurityGroupProvisioning**:
   - Typ: `AWS::EC2::SecurityGroup`
   - Beskrivning: Tillåter SSH (port 22) och HTTP (port 80) trafik till provisioning-servern.
   - Ingress-regler:
     - Tillåter SSH-åtkomst på port 22 endast från den IP-adress som specificeras i `AdminIP`.

3. **SecurityGroupASG**:
   - Typ: `AWS::EC2::SecurityGroup`
   - Beskrivning: Tillåter HTTP-trafik från ALB till Auto Scaling Group (ASG) instanser.
   - Ingress-regler:
     - Tillåter inkommande trafik på port 80 från den tidigare definierade `SecurityGroupALB`.

4. **SecurityGroupEFS**:
   - Typ: `AWS::EC2::SecurityGroup`
   - Beskrivning: Tillåter NFS-trafik (Network File System) mellan provisioning-servern och ASG.
   - Ingress-regler:
     - Tillåter inkommande trafik på port 2049 från både `SecurityGroupProvisioning` och `SecurityGroupASG`.

5. **SecurityGroupRDS**:
   - Typ: `AWS::EC2::SecurityGroup`
   - Beskrivning: Tillåter åtkomst till RDS-databasen från provisioning-servern och ASG.
   - Ingress-regler:
     - Tillåter TCP-trafik på port 3306 (standardport för MySQL och MariaDB) från `SecurityGroupProvisioning`.


Innan vi lägger till dessa säkerhetsgrupper i vår `CloudFormation.yaml`-fil, måste vi också lägga till en parameter för att definiera administratörens IP-adress. Det gör att vi kan specificera vilken IP-adress som ska ha åtkomst till provisioning-servern. Här är koden som ska läggas till i din `CloudFormation.yaml`-fil:

```yaml
Parameters:

  AdminIP:
    Type: String
    Default: 0.0.0.0/0
    Description: The IP Address of the admin.

Resources:
  # Tidigare definierade resurser...

  # Security Group ALB
  SecurityGroupALB:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: Allow HTTP and HTTPS to ALB
      VpcId: !Ref VPC
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 80
          ToPort: 80
          CidrIp: 0.0.0.0/0
        - IpProtocol: tcp
          FromPort: 443
          ToPort: 443
          CidrIp: 0.0.0.0/0
      Tags:
        - Key: Name
          Value: ALBSecurityGroup

  # Security Group Provisioning Server
  SecurityGroupProvisioning:
    Type: AWS::EC2::SecurityGroup
    DependsOn: SecurityGroupALB
    Properties:
      GroupDescription: Allow SSH and HTTP to provisioning server
      VpcId: !Ref VPC
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 22
          ToPort: 22
          CidrIp: !Ref AdminIP
      Tags:
        - Key: Name
          Value: ProvisioningSecurityGroup

  # Security Group ASG
  SecurityGroupASG:
    Type: AWS::EC2::SecurityGroup
    DependsOn: SecurityGroupProvisioning
    Properties:
      GroupDescription: Allow HTTP from ALB to ASG
      VpcId: !Ref VPC
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 80
          ToPort: 80
          SourceSecurityGroupId: !Ref SecurityGroupALB
      Tags:
        - Key: Name
          Value: ASGSecurityGroup

  # Security Group EFS
  SecurityGroupEFS:
    Type: AWS::EC2::SecurityGroup
    DependsOn:
      - SecurityGroupProvisioning
      - SecurityGroupASG
    Properties:
      GroupDescription: Allow NFS from Provisioning server and ASG
      VpcId: !Ref VPC
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 2049
          ToPort: 2049
          SourceSecurityGroupId: !Ref SecurityGroupProvisioning
        - IpProtocol: tcp
          FromPort: 2049
          ToPort: 2049
          SourceSecurityGroupId: !Ref SecurityGroupASG
      Tags:
        - Key: Name
          Value: EFSSecurityGroup

  # Security Group RDS
  SecurityGroupRDS:
    Type: AWS::EC2::SecurityGroup
    DependsOn:
      - SecurityGroupProvisioning
      - SecurityGroupASG
    Properties:
      GroupDescription: Allow RDS access from Provisioning server and ASG
      VpcId: !Ref VPC
      SecurityGroupIngress:
        - IpProtocol: tcp
          FromPort: 3306
          ToPort: 3306
          SourceSecurityGroupId: !Ref SecurityGroupProvisioning
        - IpProtocol: tcp
          FromPort: 3306
   
```
[⬆️ Till toppen](#top)


## Skapa Elastic File System (EFS)

Elastic File System (EFS) är en skalbar filsystemlösning som gör det möjligt för flera EC2-instanser att få åtkomst till filerna samtidigt. EFS är designat för att vara enkelt att använda och integreras sömlöst med andra AWS-tjänster. Det erbjuder en hög nivå av tillgänglighet och hållbarhet, vilket gör det till ett utmärkt val för lagring av delade data, såsom webbapplikationsfiler, backups och mycket mer.

För att säkerställa att EFS fungerar effektivt, behöver du skapa mount targets. Dessa mount targets gör att EC2-instanser i olika subnät kan få åtkomst till EFS. Varje mount target är kopplad till ett specifikt subnät och säkerhetsgrupp, vilket möjliggör säker och flexibel filåtkomst.

### EFS (Elastic File System)
- **EFS**: Denna resurs skapar ett Elastic File System, vilket ger en delad filsystemlösning för flera EC2-instanser, idealiskt för applikationer som kräver delad lagring.
  - **Type**: Definierar typen av resurs (AWS::EFS::FileSystem).
  - **Properties**:
    - **FileSystemTags**: Taggar som används för att identifiera och organisera resursen.
    - **BackupPolicy**: Anger att säkerhetskopiering av filsystemet är aktiverad (ENABLED).
    - **LifecyclePolicies**: Policys för livscykelhantering av data, som flyttar data till billigare lagringslösningar efter en viss tid (t.ex. efter 30 dagar till infrequent access och efter 90 dagar till arkivering).
    - **PerformanceMode**: Ställer in prestandaläget, här som generalPurpose, vilket är lämpligt för de flesta användningsfall.
    - **Encrypted**: Anger att filsystemet ska vara krypterat för ökad säkerhet.
    - **ThroughputMode**: Sätter throughput-läget till elastic, vilket gör att kapaciteten kan anpassas efter belastningen.

### Mount Targets
- **EFSMountTargetA, EFSMountTargetB, EFSMountTargetC**: Dessa resurser skapar mount targets för EFS i olika privata subnät, vilket möjliggör att EC2-instanser kan montera EFS-filsystemet.
  - **Type**: Definierar typen av resurs (AWS::EFS::MountTarget).
  - **DependsOn**: Anger att mount targets är beroende av att EFS skapas först.
  - **Properties**:
    - **FileSystemId**: Referens till det skapade EFS.
    - **SubnetId**: Anger vilket privat subnät mount target ska skapas i.
    - **SecurityGroups**: Anger säkerhetsgruppen som kommer att styra trafik till och från mount target.

För att skapa EFS och dess mount targets, lägg till följande kod i din CloudFormation-konfiguration:

```yaml
Resources:
  # Tidigare definierade resurser...
  
  # Create EFS
  EFS:
    Type: AWS::EFS::FileSystem
    Properties:
      FileSystemTags:
        - Key: Name
          Value: EFS
      BackupPolicy:
        Status: ENABLED
      LifecyclePolicies:
        - TransitionToIa: AFTER_30_DAYS
        - TransitionToArchive: AFTER_90_DAYS
      PerformanceMode: generalPurpose
      Encrypted: true
      ThroughputMode: elastic

  # Create Mount Targets
  EFSMountTargetA:
    Type: AWS::EFS::MountTarget
    DependsOn: EFS
    Properties:
      FileSystemId: !Ref EFS
      SubnetId: !Ref PrivateSubnetA
      SecurityGroups:
        - !GetAtt SecurityGroupEFS.GroupId

  EFSMountTargetB:
    Type: AWS::EFS::MountTarget
    DependsOn: EFS
    Properties:
      FileSystemId: !Ref EFS
      SubnetId: !Ref PrivateSubnetB
      SecurityGroups:
        - !GetAtt SecurityGroupEFS.GroupId

  EFSMountTargetC:
    Type: AWS::EFS::MountTarget
    DependsOn: EFS
    Properties:
      FileSystemId: !Ref EFS
      SubnetId: !Ref PrivateSubnetC
      SecurityGroups:
        - !GetAtt SecurityGroupEFS.GroupId
```

[⬆️ Till toppen](#top)

## Skapa Application Load Balancer (ALB)

Application Load Balancer (ALB) är en viktig komponent för att hantera trafik till dina applikationer på AWS. Genom att fungera som en enhetlig DNS-ingång för din miljö kan ALB dirigera användarförfrågningar till rätt resurser baserat på olika regler och konfigurationer. Denna typ av load balancer är idealisk för webbapplikationer som kräver hög tillgänglighet och lastbalansering av inkommande trafik.

ALB erbjuder också funktioner som avancerad routing, SSL-avlastning och stöd för WebSocket-protokollet, vilket gör den perfekt för moderna webbtjänster. Genom att skapa en target group kopplad till ALB kan du definiera hur trafik ska fördelas mellan dina instanser, vilket garanterar att dina applikationer är både skalbara och pålitliga.

### Application Load Balancer (ALB)
- **ALB**: Denna resurs skapar en Application Load Balancer som används för att distribuera inkommande trafik till flera instanser (t.ex. EC2-instanser) baserat på regler. 
  - **Type**: Definierar typen av resurs som skapas (AWS::ElasticLoadBalancingV2::LoadBalancer).
  - **DependsOn**: Anger beroenden som säkerställer att specifika resurser (offentliga subnät och säkerhetsgrupp) är skapade innan ALB skapas.
  - **Properties**: Innehåller specifikationer för ALB:
    - **Name**: Namnet på load balancern.
    - **Subnets**: De offentliga subnät där load balancern ska placeras.
    - **SecurityGroups**: Säkerhetsgruppen som reglerar trafik till och från load balancern.
    - **Scheme**: Anger att load balancern är internet-facing, vilket innebär att den är tillgänglig från internet.
    - **LoadBalancerAttributes**: Specifikationer för t.ex. idle timeout.
    - **Tags**: Taggar för att identifiera och organisera resurser i AWS.

### Target Group
- **TargetGroup**: Denna resurs definierar en målgrupp som ALB kommer att använda för att dirigera trafik till EC2-instanser.
  - **Type**: Definierar typen av resurs (AWS::ElasticLoadBalancingV2::TargetGroup).
  - **DependsOn**: Anger att denna resurs är beroende av VPC.
  - **Properties**:
    - **Name**: Namnet på målgruppen.
    - **Port**: Porten (80) som används för att ta emot trafik.
    - **Protocol**: Protokollet (HTTP) som används för att kommunicera med målgruppen.
    - **VpcId**: Referens till VPC där målgruppen är placerad.
    - **TargetType**: Typ av mål som trafik ska dirigeras till, här instanser.
    - **HealthCheck**: Konfiguration för hälsokontroller för att säkerställa att endast friska instanser får trafik.

### Load Balancer Listener
- **LoadBalancerListener**: Denna resurs skapar en lyssnare för ALB, vilket är den komponent som tar emot inkommande trafik.
  - **Type**: Definierar typen av resurs (AWS::ElasticLoadBalancingV2::Listener).
  - **DependsOn**: Anger att lyssnaren är beroende av både målgruppen och ALB.
  - **Properties**:
    - **DefaultActions**: Anger åtgärden som ska vidtas när trafik tas emot, här att trafik ska dirigeras till den angivna målgruppen.
    - **LoadBalancerArn**: Referens till den skapade ALB:n.
    - **Port**: Porten som lyssnaren övervakar (80).
    - **Protocol**: Protokollet (HTTP) som används.

För att skapa ALB med en lyssnare och en target group, lägg till följande kod i din CloudFormation-konfiguration:

```yaml
Resources:
  # Tidigare definierade resurser...

  # Create Application Load Balancer
  ALB:
    Type: AWS::ElasticLoadBalancingV2::LoadBalancer
    DependsOn:
      - PublicSubnetA
      - PublicSubnetB
      - PublicSubnetC
      - SecurityGroupALB
    Properties:
      Name: WordPressLoadBalancer
      Subnets:
        - !Ref PublicSubnetA
        - !Ref PublicSubnetB
        - !Ref PublicSubnetC
      SecurityGroups:
        - !Ref SecurityGroupALB
      Scheme: internet-facing
      LoadBalancerAttributes:
        - Key: idle_timeout.timeout_seconds
          Value: 60
      Tags:
        - Key: Name
          Value: ALB

  # Create Target Group for ALB
  TargetGroup:
    Type: AWS::ElasticLoadBalancingV2::TargetGroup
    DependsOn:
      - VPC
    Properties:
      Name: TargetGroup
      Port: 80
      Protocol: HTTP
      VpcId: !Ref VPC
      TargetType: instance
      HealthCheckIntervalSeconds: 30
      HealthCheckProtocol: HTTP
      HealthCheckTimeoutSeconds: 5
      HealthyThresholdCount: 5
      UnhealthyThresholdCount: 2
      Tags:
        - Key: Name
          Value: TargetGroup

  # Create Listener for ALB
  LoadBalancerListener:
    Type: AWS::ElasticLoadBalancingV2::Listener
    DependsOn:
      - TargetGroup
      - ALB
    Properties:
      DefaultActions:
        - Type: forward
          TargetGroupArn: !Ref TargetGroup
      LoadBalancerArn: !Ref ALB
      Port: 80
      Protocol: HTTP
```
[⬆️ Till toppen](#top)


## Skapa Amazon RDS för WordPress

Amazon RDS (Relational Database Service) är en hanterad databaslösning som förenklar processen att ställa in, driva och skala relationella databaser i molnet. Med RDS kan användare snabbt och enkelt distribuera en databas med hög tillgänglighet och säkerhet. Det ger automatiska säkerhetskopior, patchning, och möjligheten att enkelt skala databasen efter behov.

I detta projekt kommer RDS att fungera som den centrala databasen för WordPress, vilket gör det möjligt att lagra all webbplatsdata och innehåll på ett tillförlitligt och skalbart sätt. Genom att använda en RDS-instans säkerställer vi att databasen är optimerad för prestanda och tillgänglighet.

### RDS Subnet Group
- **DBSubnetGroup**: Denna resurs skapar en subnet group för RDS-instansen. Den specificerar vilka privata subnät (i detta fall `PrivateSubnetA`, `PrivateSubnetB`, och `PrivateSubnetC`) som databasen kommer att använda. Detta är viktigt för att säkerställa att databasen är placerad i en säker och isolerad del av VPC (Virtual Private Cloud).
  - **DBSubnetGroupDescription**: Beskrivning av subnet group.
  - **SubnetIds**: Lista över subnät som ingår i gruppen.
  - **Tags**: Taggar som kopplas till subnetgruppen.

### RDS Instance
- **RDS**: Denna resurs definierar en RDS-instans av typen MariaDB. 
  - **DBInstanceIdentifier**: Namnet på databasen, här angiven som "MariaDB".
  - **AllocatedStorage**: Den allokerade lagringskapaciteten för databasen i GB.
  - **DBInstanceClass**: Typen av instans som används, här `db.t4g.micro`, vilket är en kostnadseffektiv instanstyp för lättare belastning.
  - **Engine**: Anger vilken databasmotor som ska användas (i detta fall MariaDB).
  - **EngineVersion**: Specificerar versionen av MariaDB.
  - **MasterUsername** och **MasterUserPassword**: Referenser till användarnamn och lösenord för databasadministratören.
  - **DBName**: Namnet på databasen som ska skapas.
  - **DBSubnetGroupName**: Referens till den tidigare definierade subnetgruppen för att placera RDS-instansen i rätt subnät.
  - **VPCSecurityGroups**: Specifierar säkerhetsgruppen som ska kopplas till RDS-instansen, vilket styr åtkomsten till databasen.
  - **MultiAZ**: Anger om databasen ska köras i flera tillgänglighetszoner för hög tillgänglighet. Här är det inställt på `false`.
  - **MaxAllocatedStorage**: Den maximala lagringskapaciteten som databasen kan nå.
  - **StorageType**: Typ av lagring, här `gp3`, vilket är en typ av generisk SSD-lagring.
  - **StorageEncrypted**: Anger att lagringen ska krypteras.
  - **BackupRetentionPeriod**: Anger hur länge säkerhetskopior ska behållas. I detta fall är det inställt på `0`, vilket innebär att säkerhetskopior är avstängda.

För att skapa RDS och RDS-subnet-gruppen, lägg till följande kod i din CloudFormation-konfiguration:

```yaml
Resources:
  # Tidigare definierade resurser...

  # Create RDS Subnet Group
  DBSubnetGroup:
    Type: AWS::RDS::DBSubnetGroup
    Properties:
      DBSubnetGroupDescription: Description of subnet group
      SubnetIds:
        - !Ref PrivateSubnetA
        - !Ref PrivateSubnetB
        - !Ref PrivateSubnetC
      Tags:
        - Key: Name
          Value: DBSubnetGroup

  # Create RDS
  RDS:
    Type: AWS::RDS::DBInstance
    DependsOn: SecurityGroupRDS
    Properties:
      DBInstanceIdentifier: MariaDB
      AllocatedStorage: 20
      DBInstanceClass: db.t4g.micro
      Engine: mariadb
      EngineVersion: 11.4.3
      MasterUsername: !Ref MasterUsername
      MasterUserPassword: !Ref MasterUserPassword
      DBName: !Ref DBName
      DBSubnetGroupName: !Ref DBSubnetGroup
      VPCSecurityGroups:
        - !GetAtt SecurityGroupRDS.GroupId
      MultiAZ: false
      MaxAllocatedStorage: 1000
      StorageType: gp3
      StorageEncrypted: true
      BackupRetentionPeriod: 0 # 0 stänger av backup, ändra till antal dagar backup ska sparas
      Tags:
        - Key: Name
          Value: RDS
```

[⬆️ Till toppen](#top)
## Provisioning Server för WordPress

Provisioning-servern är en central komponent för att automatiskt installera och konfigurera WordPress på en Amazon EC2-instans. Genom att använda UserData kan vi köra ett skript vid uppstart av instansen, vilket säkerställer att alla nödvändiga programvaror och konfigurationer installeras utan manuellt arbete. Detta förenklar deployment-processen och säkerställer att miljön är konsekvent och reproducerbar.

### Förklaring av UserData-koden:
- **Systemuppdatering**: Skriptet börjar med att uppdatera alla installerade paket för att säkerställa att systemet är aktuellt.
- **Installation av NFS-verktyg**: NFS-verktygen installeras för att möjliggöra montering av EFS (Elastic File System).
- **Skapa katalog**: En katalog för webbplatsfiler skapas.
- **Montera EFS**: EFS monteras på den skapade katalogen.
- **Installera nödvändiga paket**: WordPress och dess beroenden, inklusive Apache, PHP och MariaDB, installeras.
- **Ladda ner och extrahera WordPress**: Den senaste versionen av WordPress laddas ner och extraheras.
- **Konfiguration av wp-config.php**: WordPress-konfigurationsfilen uppdateras med databasuppgifter.
- **Inställningar av rättigheter**: Ägandeskap och behörigheter sätts korrekt för webbplatsens filer.
- **Installera och konfigurera WP-CLI**: WP-CLI installeras för att underlätta WordPress-administrationen.
- **Slutinstallera WordPress**: WordPress installeras med hjälp av WP-CLI med angivna parametrar.

### Sektion 1: Instanskonfiguration
Nedan är koden som används för att skapa provisioning-servern och utföra installationen av WordPress:

```yaml
Resources:
  # Tidigare definierade resurser...

  # Create Provisioning Server
  WordPressProvisioning:
    Type: AWS::EC2::Instance
    DependsOn:
      - SecurityGroupProvisioning
      - EFSMountTargetA
      - EFSMountTargetB
      - EFSMountTargetC
      - RDS
      - ALB
    Properties:
      InstanceType: t2.micro
      ImageId: !Ref LatestAmiId
      KeyName: !Ref SSHKey
      SecurityGroupIds:
        - !Ref SecurityGroupProvisioning
      SubnetId: !Ref PublicSubnetA
      UserData: 
        Fn::Base64: !Sub |
          #!/bin/bash
          # Update all packages to the latest version
          dnf update -y
          # Install the NFS utilities to allow mounting of EFS (Elastic File System)
          dnf install nfs-utils -y
          # Create a directory for the website files
          mkdir -p /var/www/html
          # Mount the Amazon EFS file system to the /var/www/html directory
          mount -t nfs4 -o nfsvers=4.1 ${EFS}.efs.${AWS::Region}.amazonaws.com:/ /var/www/html
          # Install required packages: wget, PHP, Apache HTTP Server, and MariaDB
          dnf install -y wget php-mysqlnd httpd php-fpm php-mysqli mariadb105-server php-json php php-devel php-gd
          # Start the Apache HTTP Server
          systemctl start httpd
          # Download the latest version of WordPress
          wget https://wordpress.org/latest.tar.gz
          # Extract the WordPress archive
          tar -xzf latest.tar.gz
          # Copy the sample WordPress configuration file to create a new configuration
          cp wordpress/wp-config-sample.php wordpress/wp-config.php
          # Set database configuration details in the wp-config file
          sed -i "s/database_name_here/${DBName}/" wordpress/wp-config.php
          sed -i "s/username_here/${MasterUsername}/" wordpress/wp-config.php
          sed -i "s/password_here/${MasterUserPassword}/" wordpress/wp-config.php
          sed -i "s/localhost/${RDS.Endpoint.Address}/" wordpress/wp-config.php
          sed -i "1 a\define('WP_HOME', 'http://${ALB.DNSName}');" wordpress/wp-config.php
          sed -i "2 a\define('WP_SITEURL', 'http://${ALB.DNSName}');" wordpress/wp-config.php
          # Fetch security salts from WordPress API and add to configuration file
          curl -s https://api.wordpress.org/secret-key/1.1/salt/ >> new-salts.php
          sed -i '/AUTH_KEY/,/NONCE_SALT/ {
            /AUTH_KEY/ r new-salts.php
            d
          }' wordpress/wp-config.php
          # Copy WordPress files to the web root directory
          cp -r wordpress/* /var/www/html/
          # Update the Apache configuration to allow .htaccess overrides in the web root
          sed -i 's/^\( *AllowOverride\) None/\1 All/' /etc/httpd/conf/httpd.conf
          # Set ownership and permissions for web files and directories
          chown -R apache:apache /var/www
          chmod 2775 /var/www
          # Set permissions for all directories to allow group write and setgid
          find /var/www -type d -exec chmod 2775 {} \;
          # Set permissions for all files to read and write for the owner and read-only for others
          find /var/www -type f -exec chmod 0644 {} \;
          # Restart the Apache service to apply changes
          systemctl restart httpd
          # Install WP-CLI
          curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
          chmod +x wp-cli.phar
          mv wp-cli.phar /usr/local/bin/wp
          # Install WordPress using WP-CLI as the appropriate user
          cd /var/www/html
          wp core install --url=${ALB.DNSName} --title='${WPTitle}' --admin_user=${WPAdminUser} --admin_password=${WPAdminPassword} --admin_email=${WPAdminEmail} --allow-root
          # Clean up downloaded files
          rm -rf ~/latest.tar.gz ~/wordpress ~/new-salts.php

      Tags:
        - Key: Name
          Value: WordPressProvisioningServer
```

### Parametrar

För att koden ska fungera korrekt måste följande parametrar definieras under sektionen `Parameters`. Dessa parametrar används i instanskonfigurationen för att anpassa installationen av WordPress och dess databas. Varje parameter har en beskrivning som förklarar dess syfte, vilket gör det enklare att förstå vad varje parameter används till. 

### Viktigt att notera
- **Parametrarna** måste anges korrekt i sektionen `Parameters` för att skriptet ska kunna referera till dem i instanskonfigurationen.
- När du skapar stacken i CloudFormation kan du ange värden för dessa parametrar, vilket gör installationen av WordPress anpassad och säker.

#### Parametrar som ska definieras:
```yaml
Parameters:
  LatestAmiId:
    Description: Region specific image from the Parameter Store
    Type: AWS::SSM::Parameter::Value<AWS::EC2::Image::Id>
    Default: /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64

  SSHKey:
    Type: String
    Description: Name of the ssh key pair.

  MasterUsername:
    Type: String
    Default: admin
    Description: The master username for the RDS database

  MasterUserPassword:
    Type: String
    NoEcho: true
    Description: The master password for the RDS database

  DBName:
    Type: String
    Default: "wordpressdb"
    Description: The name of the database to create

  WPTitle:
    Type: String
    Default: "My WordPress Site"
    Description: "The title of your WordPress site"

  WPAdminUser:
    Type: String
    Default: "admin"
    Description: "The username for the WordPress admin account"

  WPAdminPassword:
    Type: String
    NoEcho: true
    Description: "The password for the WordPress admin account"

  WPAdminEmail:
    Type: String
    Default: "admin@example.com"
    Description: "The email address for the WordPress admin account"
```

[⬆️ Till toppen](#top)

## Launch Template

Launch Templates är en viktig komponent för att definiera konfigurationen av instanser i AWS. En Launch Template specificerar instanstyp, säkerhetsgrupper och UserData, som körs vid start av instansen. Genom att använda Launch Templates kan vi enkelt skapa och hantera instanser med en enhetlig konfiguration.

### Förklaring av koden:
- **Launch Template**:
  - **Type**: Definierar resursen som en Launch Template.
  - **LaunchTemplateData**: Innehåller instanskonfigurationer såsom instanstyp, AMI-id och säkerhetsgrupper.
  - **UserData**: Skriptet som körs vid instansens start, installerar nödvändiga paket och konfigurerar servrar.
  - **TagSpecifications**: Specificerar taggar för instanser som skapas från denna mall.


Nedan är koden för att skapa en Launch Template för LAMP-servrar:

```yaml
Resources:
  # Create Launch Template for LAMP servers
  LaunchTemplate:
    Type: AWS::EC2::LaunchTemplate
    DependsOn:
      - WordPressProvisioning
    Properties:
      LaunchTemplateName: LampServer
      LaunchTemplateData:
        InstanceType: t2.micro
        ImageId: !Ref LatestAmiId
        KeyName: !Ref SSHKey
        SecurityGroupIds:
          - !Ref SecurityGroupASG
        UserData: !Base64
          Fn::Sub: |
            #!/bin/bash
            dnf update -y
            dnf install nfs-utils -y
            mkdir -p /var/www/html
            mount -t nfs4 -o nfsvers=4.1 ${EFS}.efs.${AWS::Region}.amazonaws.com:/ /var/www/html
            dnf install wget php-mysqlnd httpd php-fpm php-mysqli mariadb105-server php-json php php-devel -y
            sed -i 's/^\( *AllowOverride\) None/\1 All/' /etc/httpd/conf/httpd.conf
            systemctl start httpd
        TagSpecifications:
          - ResourceType: instance
            Tags:
              - Key: Name
                Value: LAMPServer
```
[⬆️ Till toppen](#top)
## Auto Scaling Group

Auto Scaling Groups är avgörande för att automatiskt hantera antalet instanser baserat på trafikbelastning och andra parametrar. Genom att använda en Auto Scaling Group kan vi säkerställa hög tillgänglighet och kostnadseffektivitet i vår infrastruktur. Auto Scaling Groups arbetar med Launch Templates för att skala upp eller ner antalet instanser efter behov.

- **Auto Scaling Group**:
  - **Type**: Definierar resursen som en Auto Scaling Group.
  - **LaunchTemplate**: Referens till den skapade Launch Template.
  - **MinSize**, **MaxSize**, **DesiredCapacity**: Definierar antalet instanser som ska köras.
  - **VPCZoneIdentifier**: Definierar subnät där instanserna ska placeras.
  - **TargetGroupARNs**: Referens till Target Group för att dirigera trafik till instanserna.
  - **Tags**: Taggar som kopplas till Auto Scaling Group.

Nedan är koden för att skapa en Auto Scaling Group för WordPress:

```yaml
  # Create Auto Scaling Group for WordPress
  ASG:
    Type: AWS::AutoScaling::AutoScalingGroup
    DependsOn:
      - WordPressProvisioning
    Properties:
      AutoScalingGroupName: !Sub AutoScalingGroup
      LaunchTemplate:
        LaunchTemplateId: !Ref LaunchTemplate
        Version: !GetAtt LaunchTemplate.LatestVersionNumber
      MinSize: 1
      MaxSize: 3
      DesiredCapacity: 1
      VPCZoneIdentifier:
        - !Ref PublicSubnetA
        - !Ref PublicSubnetB
        - !Ref PublicSubnetC
      TargetGroupARNs:
        - !Ref TargetGroup
      Tags:
        - Key: Name
          Value: AutoScalingGroup
          PropagateAtLaunch: true
```
[⬆️ Till toppen](#top)
## AdminServer

**AdminServer** är en EC2-instans som tillhandahåller en säker plattform för att hantera resurser som Elastic File System (EFS) och Amazon RDS. Genom att använda SSH kan du enkelt fjärråtkomst till instansen och utföra nödvändiga operationer för att administrera din WordPress-installation och dess databas. Denna instans installeras med nödvändiga verktyg och konfigurationer för att säkerställa en smidig drift.

### Förklaring av UserData-koden:
- **Systemuppdatering**: Skriptet börjar med att uppdatera alla installerade paket för att säkerställa att systemet är aktuellt.
- **Installation av NFS-verktyg**: NFS-verktygen installeras för att möjliggöra montering av EFS.
- **Skapa katalog**: En katalog för webbplatsfiler skapas.
- **Montera EFS**: EFS monteras på den skapade katalogen och läggs till i `/etc/fstab` för automatisk montering vid systemstart.
- **Installation av nödvändiga paket**: Nödvändiga paket, inklusive wget, PHP och Apache, installeras.
- **Inställningar av rättigheter**: Apache-konfigurationen justeras för att tillåta användning av `.htaccess`-filer.
- **Start av Apache**: Apache-tjänsten startas för att möjliggöra webbserverdrift.

Genom att ha **AdminServer** installerad kan du enkelt hantera och administrera dina resurser och säkerställa att din WordPress-installation är stabil och välkonfigurerad.

Läggt till följande kodunder Resources.
```yaml
# Create Provisioning Server
AdminServer:
  Type: AWS::EC2::Instance
  DependsOn:
    - ASG
  Properties:
    InstanceType: t2.micro
    ImageId: !Ref LatestAmiId
    KeyName: !Ref SSHKey
    SecurityGroupIds:
      - !Ref SecurityGroupProvisioning
    SubnetId: !Ref PublicSubnetA
    UserData: 
      Fn::Base64: !Sub |
        #!/bin/bash
        # Update all packages to the latest version
        dnf update -y
        # Install NFS utilities for mounting EFS
        dnf install nfs-utils -y
        # Create directory for web files
        mkdir -p /var/www/html
        # Mount EFS to the created directory
        mount -t nfs4 -o nfsvers=4.1 ${EFS}.efs.${AWS::Region}.amazonaws.com:/ /var/www/html
        # Add EFS to fstab for automatic mounting on boot
        echo "${EFS}.efs.${AWS::Region}.amazonaws.com:/ /var/www/html nfs4 defaults,_netdev 0 0" >> /etc/fstab
        # Install required packages
        dnf install wget php-mysqlnd httpd php-fpm php-mysqli mariadb105-server php-json php php-devel -y
        # Allow .htaccess overrides in Apache configuration
        sed -i 's/^\( *AllowOverride\) None/\1 All/' /etc/httpd/conf/httpd.conf
        # Start the Apache HTTP Server
        systemctl start httpd
    Tags:
      - Key: Name
        Value: AdminServer
```
[⬆️ Till toppen](#top)

## Deploy-skript för WordPress-miljö

För att köra denna CloudFormation-mall och skapa din WordPress-miljö, skapa ett skript som kör följande kommando. Skriptet innehåller alla nödvändiga parametrar och säkerställer att installationen anpassas enligt dina behov.


### Kort om skriptet:
1. **ADMIN_IP**: Denna variabel lagrar den IP-adress som ska användas för att ge SSH-åtkomst till provisioning-servern. Den är inställd på `213.321.3.321/32`, som är din hem-IP. Byt ut detta mot din faktiska IP-adress om det behövs.
2. **aws cloudformation deploy**: Denna kommando används för att initiera skapandet av CloudFormation-stack. Den anger den specifika mallen (`CloudFormation.yaml`) och namnet på stacken (`uppgift2`).
3. **--parameter-overrides**: Här anges värden för de parametrar som definieras i din CloudFormation-mall. Dessa parametrar anpassar installationen av WordPress.
4. **Output**: Skriptet ger en bekräftelse att distributionen av stacken har påbörjats.

### Användning:
- Spara skriptet i en fil, exempelvis `deploy.sh`.
- Kör skriptet: `./deploy.sh` för att starta distributionen av din WordPress-miljö.

Se till att AWS CLI är korrekt konfigurerat och att du har de nödvändiga rättigheterna för att skapa resurser i ditt AWS-konto.

```bash
#!/bin/bash

# Deploy script to create the WordPress environment using CloudFormation

# Define the admin IP address. Change this to your specific admin IP.
ADMIN_IP="213.321.3.321/32"  # Replace with your actual IP address

# Execute the CloudFormation deploy command
aws cloudformation deploy \
  --template-file CloudFormation.yaml \
  --stack-name uppgift2 \
  --parameter-overrides \
    AdminIP=$ADMIN_IP \
    SSHKey=ssh \
    MasterUsername=rds-username \
    MasterUserPassword=kod-till-rds \
    DBName=wordpressdb-namn \
    WPTitle=wordpresstitel \
    WPAdminUser=wordpress-user \
    WPAdminPassword=wordpress-kod \
    WPAdminEmail=admin@mail.se
```

### Påminnelse:
Efter att din WordPress-miljö har skapats, se till att du tar bort provisioning-servern för att upprätthålla säkerheten. Att ha onödiga resurser som kan ge åtkomst till systemet är en potentiell säkerhetsrisk, så det är en god praxis att ta bort dem när de inte längre behövs. 

Du kan använda AWS Management Console eller CLI för att ta bort provisioning-servern genom att radera stacken eller den specifika resursen.

[⬆️ Till toppen](#top)

## Radera Stack vid labb

För att radera den skapade miljön och undvika onödiga kostnader, särskilt om miljön används för labbsyften, kan du använda följande kommando:

```bash
aws cloudformation delete-stack --stack-name uppgift2
```

Detta kommando kommer att radera stack `uppgift2` och alla tillhörande resurser som skapades under deployment-processen. 

### Viktigt
Se till att du har sparat alla viktiga data innan du kör kommandot, eftersom alla resurser som är kopplade till stakken kommer att tas bort permanent. Att radera stacken är en bra praxis för att hålla kostnaderna nere och förhindra att onödiga resurser kvarstår i din AWS-miljö.

[⬆️ Till toppen](#top)