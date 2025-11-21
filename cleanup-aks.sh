#!/usr/bin/env bash

set -e

# Variables configurables
AKS_NAMESPACE="${AKS_NAMESPACE:-default}"

# Colores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "🧹 Limpiando todos los deployments en AKS (namespace: $AKS_NAMESPACE)..."
echo ""

# Verificar que kubectl esté configurado
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}❌ No se puede conectar al cluster. Configura kubeconfig primero.${NC}"
    exit 1
fi

# Verificar que el namespace existe
if ! kubectl get namespace "$AKS_NAMESPACE" &> /dev/null; then
    echo -e "${YELLOW}⚠️  El namespace '$AKS_NAMESPACE' no existe. Nada que limpiar.${NC}"
    exit 0
fi

# Eliminar todos los deployments
echo -e "${YELLOW}Eliminando deployments...${NC}"
kubectl delete deployment service-discovery cloud-config zipkin api-gateway \
  order-service user-service product-service payment-service \
  shipping-service favourite-service proxy-client -n "$AKS_NAMESPACE" 2>/dev/null || true

echo ""
echo "⏳ Esperando a que los pods terminen..."
sleep 5

echo ""
echo "📋 Pods restantes:"
kubectl get pods -n "$AKS_NAMESPACE"

echo ""
echo "📋 Deployments restantes:"
kubectl get deployments -n "$AKS_NAMESPACE"

echo ""
echo -e "${GREEN}✅ Limpieza completada${NC}"
echo ""
echo "💡 Para verificar que todo se eliminó:"
echo "   kubectl get pods -n $AKS_NAMESPACE"
echo "   kubectl get deployments -n $AKS_NAMESPACE"
echo ""

