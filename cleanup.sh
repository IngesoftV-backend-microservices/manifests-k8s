#!/usr/bin/env bash

set -e

echo "🧹 Limpiando todos los deployments..."

# Eliminar todos los deployments
kubectl delete deployment service-discovery cloud-config zipkin api-gateway \
  order-service user-service product-service payment-service \
  shipping-service favourite-service proxy-client 2>/dev/null || true

echo ""
echo "⏳ Esperando a que los pods terminen..."
sleep 5

echo ""
echo "📋 Pods restantes:"
kubectl get pods

echo ""
echo "✅ Limpieza completada"
echo ""
echo "💡 Para verificar que todo se eliminó:"
echo "   kubectl get pods"
echo "   kubectl get deployments"

