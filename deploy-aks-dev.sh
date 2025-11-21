#!/usr/bin/env bash

set -e

echo "🚀 Desplegando servicios en AKS con perfil DEV..."
echo ""

# Colores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Variables configurables (pueden pasarse como argumentos o variables de entorno)
AKS_RESOURCE_GROUP="${AKS_RESOURCE_GROUP:-}"
AKS_CLUSTER_NAME="${AKS_CLUSTER_NAME:-}"
AKS_NAMESPACE="${AKS_NAMESPACE:-default}"

# Función para mostrar uso
usage() {
    cat <<EOF
Uso: $0 [OPTIONS]

Opciones:
  -g, --resource-group NAME    Nombre del resource group de AKS
  -c, --cluster-name NAME       Nombre del cluster AKS
  -n, --namespace NAME          Namespace de Kubernetes (default: default)
  -h, --help                    Mostrar esta ayuda

Variables de entorno:
  AKS_RESOURCE_GROUP            Nombre del resource group
  AKS_CLUSTER_NAME              Nombre del cluster AKS
  AKS_NAMESPACE                 Namespace (default: default)

Ejemplos:
  $0 -g myResourceGroup -c myAKSCluster
  AKS_RESOURCE_GROUP=myRG AKS_CLUSTER_NAME=myCluster $0
EOF
}

# Parsear argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        -g|--resource-group)
            AKS_RESOURCE_GROUP="$2"
            shift 2
            ;;
        -c|--cluster-name)
            AKS_CLUSTER_NAME="$2"
            shift 2
            ;;
        -n|--namespace)
            AKS_NAMESPACE="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Opción desconocida: $1${NC}"
            usage
            exit 1
            ;;
    esac
done

# Validar que se proporcionaron los parámetros necesarios
if [[ -z "$AKS_RESOURCE_GROUP" ]] || [[ -z "$AKS_CLUSTER_NAME" ]]; then
    echo -e "${RED}❌ Error: Se requiere AKS_RESOURCE_GROUP y AKS_CLUSTER_NAME${NC}"
    echo ""
    usage
    exit 1
fi

# 1. Verificar que Azure CLI esté instalado
echo -e "${YELLOW}1. Verificando Azure CLI...${NC}"
if ! command -v az &> /dev/null; then
    echo -e "${RED}❌ Azure CLI no está instalado. Instálalo desde: https://docs.microsoft.com/cli/azure/install-azure-cli${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Azure CLI está instalado${NC}"
echo ""

# 2. Verificar que estás autenticado en Azure
echo -e "${YELLOW}2. Verificando autenticación en Azure...${NC}"
if ! az account show &> /dev/null; then
    echo -e "${YELLOW}⚠️  No estás autenticado. Ejecutando az login...${NC}"
    az login
fi
echo -e "${GREEN}✅ Autenticado en Azure${NC}"
echo ""

# 3. Verificar que el cluster AKS existe
echo -e "${YELLOW}3. Verificando que el cluster AKS existe...${NC}"
if ! az aks show --resource-group "$AKS_RESOURCE_GROUP" --name "$AKS_CLUSTER_NAME" &> /dev/null; then
    echo -e "${RED}❌ El cluster AKS '$AKS_CLUSTER_NAME' no existe en el resource group '$AKS_RESOURCE_GROUP'${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Cluster AKS encontrado${NC}"
echo ""

# 4. Configurar kubeconfig para AKS
echo -e "${YELLOW}4. Configurando kubeconfig para AKS...${NC}"
az aks get-credentials --resource-group "$AKS_RESOURCE_GROUP" --name "$AKS_CLUSTER_NAME" --overwrite-existing
echo -e "${GREEN}✅ Kubeconfig configurado${NC}"
echo ""

# 5. Verificar que kubectl puede conectarse al cluster
echo -e "${YELLOW}5. Verificando conexión al cluster...${NC}"
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}❌ No se puede conectar al cluster AKS${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Conectado al cluster AKS${NC}"
echo ""

# 6. Crear namespace si no existe
echo -e "${YELLOW}6. Verificando namespace '${AKS_NAMESPACE}'...${NC}"
if ! kubectl get namespace "$AKS_NAMESPACE" &> /dev/null; then
    echo "   Creando namespace..."
    kubectl create namespace "$AKS_NAMESPACE"
    echo -e "${GREEN}✅ Namespace creado${NC}"
else
    echo -e "${GREEN}✅ Namespace ya existe${NC}"
fi
echo ""

# 7. Desplegar infraestructura primero (Eureka debe estar primero)
echo -e "${YELLOW}7. Desplegando core...${NC}"
kubectl apply -n "$AKS_NAMESPACE" -f k8s/cloud-config-deployment.yaml
kubectl apply -n "$AKS_NAMESPACE" -f k8s/eureka-deployment.yaml
kubectl apply -n "$AKS_NAMESPACE" -f k8s/zipkin-deployment.yaml
echo -e "${GREEN}✅ Core desplegado${NC}"
echo ""

# 8. Esperar a que Eureka esté listo (crítico)
echo -e "${YELLOW}8. Esperando a que Eureka esté listo...${NC}"
kubectl rollout status deployment/service-discovery -n "$AKS_NAMESPACE" --timeout=360s
echo -e "${GREEN}✅ Eureka está listo${NC}"
echo ""

# 9. Esperar a que Cloud Config esté listo
echo -e "${YELLOW}9. Esperando a que Cloud Config esté listo...${NC}"
kubectl rollout status deployment/cloud-config -n "$AKS_NAMESPACE" --timeout=360s || echo "⚠️  Cloud Config puede tardar más"
echo ""

# 10. Desplegar API Gateway
echo -e "${YELLOW}10. Desplegando API Gateway...${NC}"
kubectl apply -n "$AKS_NAMESPACE" -f k8s/api-gateway-deployment.yaml
echo ""

# 11. Desplegar todos los microservicios
echo -e "${YELLOW}11. Desplegando microservicios...${NC}"
kubectl apply -n "$AKS_NAMESPACE" -f k8s/order-deployment.yaml
kubectl apply -n "$AKS_NAMESPACE" -f k8s/user-deployment.yaml
kubectl apply -n "$AKS_NAMESPACE" -f k8s/product-deployment.yaml
kubectl apply -n "$AKS_NAMESPACE" -f k8s/payment-deployment.yaml
kubectl apply -n "$AKS_NAMESPACE" -f k8s/shipping-deployment.yaml
kubectl apply -n "$AKS_NAMESPACE" -f k8s/favourite-deployment.yaml
kubectl apply -n "$AKS_NAMESPACE" -f k8s/proxy-client-deployment.yaml
echo -e "${GREEN}✅ Todos los microservicios desplegados${NC}"
echo ""

# 12. Verificar estado de los pods
echo -e "${YELLOW}12. Estado de los pods:${NC}"
kubectl get pods -n "$AKS_NAMESPACE"
echo ""

# 13. Esperar a que los servicios críticos estén listos
echo -e "${YELLOW}13. Esperando a que los servicios estén listos...${NC}"
echo "Esto puede tardar unos minutos..."
kubectl wait --for=condition=ready pod -l app=api-gateway -n "$AKS_NAMESPACE" --timeout=360s || true
kubectl wait --for=condition=ready pod -l app=order-service -n "$AKS_NAMESPACE" --timeout=360s || true
kubectl wait --for=condition=ready pod -l app=user-service -n "$AKS_NAMESPACE" --timeout=360s || true
kubectl wait --for=condition=ready pod -l app=product-service -n "$AKS_NAMESPACE" --timeout=360s || true
kubectl wait --for=condition=ready pod -l app=payment-service -n "$AKS_NAMESPACE" --timeout=360s || true
kubectl wait --for=condition=ready pod -l app=shipping-service -n "$AKS_NAMESPACE" --timeout=360s || true
kubectl wait --for=condition=ready pod -l app=favourite-service -n "$AKS_NAMESPACE" --timeout=360s || true
kubectl wait --for=condition=ready pod -l app=proxy-client -n "$AKS_NAMESPACE" --timeout=360s || true

echo ""
echo -e "${GREEN}✅ Despliegue completado${NC}"
echo ""
echo "📋 Para ver los pods:"
echo "   kubectl get pods -n $AKS_NAMESPACE"
echo ""
echo "📋 Para ver los servicios:"
echo "   kubectl get svc -n $AKS_NAMESPACE"
echo ""
echo "📋 Para ver Eureka:"
echo "   kubectl port-forward svc/service-discovery 8761:8761 -n $AKS_NAMESPACE"
echo "   Luego abrir: http://localhost:8761"
echo ""
echo "📋 Para ver API Gateway:"
echo "   kubectl port-forward svc/api-gateway 8080:8080 -n $AKS_NAMESPACE"
echo "   Luego abrir: http://localhost:8080"
echo ""
echo "📋 Para ver logs de un servicio:"
echo "   kubectl logs -f deployment/order-service -n $AKS_NAMESPACE"
echo ""
echo "📋 Para obtener la URL externa de un servicio (si usa LoadBalancer):"
echo "   kubectl get svc -n $AKS_NAMESPACE"
echo ""

