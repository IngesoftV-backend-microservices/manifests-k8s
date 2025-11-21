#!/usr/bin/env bash

set -e

echo "🚀 Desplegando servicios en Minikube con perfil DEV..."
echo ""

# Colores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. Verificar que minikube esté corriendo
echo -e "${YELLOW}1. Verificando minikube...${NC}"
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Minikube no está corriendo. Inicia con: minikube start"
    exit 1
fi
echo -e "${GREEN}✅ Minikube está corriendo${NC}"
echo ""

# 2. Desplegar infraestructura primero (Eureka debe estar primero)
echo -e "${YELLOW}2. Desplegando core...${NC}"
kubectl apply -f k8s/eureka-deployment.yaml
kubectl apply -f k8s/cloud-config-deployment.yaml
kubectl apply -f k8s/zipkin-deployment.yaml
echo -e "${GREEN}✅ Core desplegado${NC}"
echo ""

# 3. Esperar a que Eureka esté listo (crítico)
echo -e "${YELLOW}3. Esperando a que Eureka esté listo...${NC}"
kubectl rollout status deployment/service-discovery --timeout=360s
echo -e "${GREEN}✅ Eureka está listo${NC}"
echo ""

# 4. Esperar a que Cloud Config esté listo
echo -e "${YELLOW}4. Esperando a que Cloud Config esté listo...${NC}"
kubectl rollout status deployment/cloud-config --timeout=360s || echo "⚠️  Cloud Config puede tardar más"
echo ""

# 5. Desplegar API Gateway
echo -e "${YELLOW}5. Desplegando API Gateway...${NC}"
kubectl apply -f k8s/api-gateway-deployment.yaml
echo ""

# 6. Desplegar todos los microservicios
echo -e "${YELLOW}6. Desplegando microservicios...${NC}"
kubectl apply -f k8s/order-deployment.yaml
kubectl apply -f k8s/user-deployment.yaml
kubectl apply -f k8s/product-deployment.yaml
kubectl apply -f k8s/payment-deployment.yaml
kubectl apply -f k8s/shipping-deployment.yaml
kubectl apply -f k8s/favourite-deployment.yaml
kubectl apply -f k8s/proxy-client-deployment.yaml
echo -e "${GREEN}✅ Todos los microservicios desplegados${NC}"
echo ""

# 7. Verificar estado de los pods
echo -e "${YELLOW}7. Estado de los pods:${NC}"
kubectl get pods
echo ""

# 8. Esperar a que los servicios críticos estén listos
echo -e "${YELLOW}8. Esperando a que los servicios estén listos...${NC}"
echo "Esto puede tardar unos minutos..."
kubectl wait --for=condition=ready pod -l app=api-gateway --timeout=360s || true
kubectl wait --for=condition=ready pod -l app=order-service --timeout=360s || true
kubectl wait --for=condition=ready pod -l app=user-service --timeout=360s || true

echo ""
echo -e "${GREEN}✅ Despliegue completado${NC}"
echo ""
echo "📋 Para ver los pods:"
echo "   kubectl get pods"
echo ""
echo "📋 Para ver los servicios:"
echo "   kubectl get svc"
echo ""
echo "📋 Para ver Eureka:"
echo "   kubectl port-forward svc/service-discovery 8761:8761"
echo "   Luego abrir: http://localhost:8761"
echo ""
echo "📋 Para ver API Gateway:"
echo "   kubectl port-forward svc/api-gateway 8080:8080"
echo "   Luego abrir: http://localhost:8080"
echo ""
echo "📋 Para ver logs de un servicio:"
echo "   kubectl logs -f deployment/order-service"
echo ""

