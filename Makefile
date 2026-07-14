NAMESPACE := voting-app
RESULT_TAG := v1.0.0
WORKER_TAG := v1.0.0

.PHONY: demo

demo:
	@echo "Starting Minikube..."
	@if ! minikube status >/dev/null 2>&1; then \
		minikube start --driver=docker --cpus=2 --memory=4096; \
	fi

	@echo "Enabling addons..."
	minikube addons enable ingress
	minikube addons enable metrics-server

	kubectl rollout status deployment/ingress-nginx-controller \
		-n ingress-nginx \
		--timeout=300s

	kubectl wait \
		--namespace ingress-nginx \
		--for=condition=Ready pod \
		-l app.kubernetes.io/component=controller \
		--timeout=300s

	@echo "Starting Minikube tunnel..."
	@if ! pgrep -f "minikube tunnel" >/dev/null; then \
		echo "Enter your password to allow minikube tunnel to create network routes:"; \
		sudo -v; \
		sudo nohup minikube tunnel >/dev/null 2>&1 & \
		sleep 5; \
	fi

	@if ! docker image inspect naveen9521/result-app:$(RESULT_TAG) >/dev/null 2>&1; then \
		docker build -t naveen9521/result-app:$(RESULT_TAG) ./result; \
	fi
	minikube image load naveen9521/result-app:$(RESULT_TAG)

	@if ! docker image inspect naveen9521/worker-app:$(WORKER_TAG) >/dev/null 2>&1; then \
		docker build -t naveen9521/worker-app:$(WORKER_TAG) ./worker; \
	fi
	minikube image load naveen9521/worker-app:$(WORKER_TAG)

	kubectl create namespace $(NAMESPACE) \
		--dry-run=client -o yaml | kubectl apply -f -

	kubectl apply -f k8s-specifications/ -n $(NAMESPACE)

	kubectl rollout restart deployment/result -n $(NAMESPACE)
	kubectl rollout restart deployment/vote -n $(NAMESPACE)
	kubectl rollout restart deployment/worker -n $(NAMESPACE)

	kubectl rollout status statefulset/db -n $(NAMESPACE)
	kubectl rollout status statefulset/redis -n $(NAMESPACE)

	kubectl rollout status deployment/vote -n $(NAMESPACE)
	kubectl rollout status deployment/worker -n $(NAMESPACE)
	kubectl rollout status deployment/result -n $(NAMESPACE)

	@echo "Updating /etc/hosts..."
	@if grep -q "votingapp.local" /etc/hosts; then \
		sudo sed -i.bak '/votingapp.local/d' /etc/hosts; \
	fi

	@echo "127.0.0.1 votingapp.local" | sudo tee -a /etc/hosts >/dev/null

	@echo ""
	@echo "Deployment completed successfully!"
	@echo "Vote App   : http://votingapp.local/"
	@echo "Result App : http://votingapp.local/result"
	@echo ""

	kubectl get pods -n $(NAMESPACE)
	kubectl get svc -n $(NAMESPACE)
	kubectl get ingress -n $(NAMESPACE)