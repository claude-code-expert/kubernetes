/*
M33 — JournalSite 컨트롤러.

조정 함수 하나가 전부다. 이 함수는 다음 셋을 지켜야 한다.
  1) 멱등하다 — 몇 번을 불러도 결과가 같다
  2) 전체를 다시 계산한다 — "무엇이 바뀌었는지"를 인자로 받지 않는다
  3) 빨리 끝난다 — 오래 걸릴 일은 requeue 로 나눈다
*/

package controller

import (
	"context"
	"fmt"

	"k8s.io/apimachinery/pkg/util/intstr"

	appsv1 "k8s.io/api/apps/v1"
	corev1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/api/errors"
	"k8s.io/apimachinery/pkg/api/resource"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/log"

	studyv1alpha1 "example.com/journalsite-operator/api/v1alpha1"
)

type JournalSiteReconciler struct {
	client.Client
	Scheme *runtime.Scheme
}

// +kubebuilder:rbac:groups=study.example.com,resources=journalsites,verbs=get;list;watch;create;update;patch;delete
// +kubebuilder:rbac:groups=study.example.com,resources=journalsites/status,verbs=get;update;patch
// +kubebuilder:rbac:groups=study.example.com,resources=journalsites/finalizers,verbs=update
// +kubebuilder:rbac:groups=apps,resources=deployments,verbs=get;list;watch;create;update;patch;delete

func (r *JournalSiteReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	logger := log.FromContext(ctx)

	// ① 원하는 상태를 읽는다.
	var site studyv1alpha1.JournalSite
	if err := r.Get(ctx, req.NamespacedName, &site); err != nil {
		// 이미 지워졌으면 할 일이 없다. 오브젝트에 붙인 것은 가비지 컬렉터가 치운다.
		return ctrl.Result{}, client.IgnoreNotFound(err)
	}

	// ② 있어야 할 디플로이먼트를 계산한다.
	want := r.desiredDeployment(&site)
	// 소유자를 박아 둔다. 이것이 없으면 JournalSite 를 지워도 디플로이먼트가 남는다.
	if err := ctrl.SetControllerReference(&site, want, r.Scheme); err != nil {
		return ctrl.Result{}, err
	}

	var have appsv1.Deployment
	err := r.Get(ctx, client.ObjectKeyFromObject(want), &have)
	switch {
	case errors.IsNotFound(err):
		logger.Info("디플로이먼트를 만든다", "name", want.Name)
		if err := r.Create(ctx, want); err != nil {
			return ctrl.Result{}, err
		}
	case err != nil:
		return ctrl.Result{}, err
	default:
		// 이미 있으면 우리가 관리하는 필드만 맞춘다.
		// 전체를 덮으면 다른 컨트롤러(HPA 등)가 정한 값을 지운다.
		changed := false
		if *have.Spec.Replicas != site.Spec.Replicas {
			have.Spec.Replicas = &site.Spec.Replicas
			changed = true
		}
		if have.Spec.Template.Spec.Containers[0].Image != site.Spec.Image {
			have.Spec.Template.Spec.Containers[0].Image = site.Spec.Image
			changed = true
		}
		if changed {
			logger.Info("디플로이먼트를 고친다", "name", have.Name)
			if err := r.Update(ctx, &have); err != nil {
				return ctrl.Result{}, err
			}
		}
	}

	// ③ status 를 갱신한다. spec 과 다른 서브리소스라 서로 충돌하지 않는다.
	var current appsv1.Deployment
	if err := r.Get(ctx, client.ObjectKeyFromObject(want), &current); err == nil {
		ready := current.Status.ReadyReplicas
		phase := "Progressing"
		condStatus := metav1.ConditionFalse
		reason := "NotReady"
		if ready == site.Spec.Replicas {
			phase = "Ready"
			condStatus = metav1.ConditionTrue
			reason = "AllReplicasReady"
		}
		site.Status.ReadyReplicas = ready
		site.Status.Phase = phase
		// 관측한 세대를 남긴다. 이것이 spec 의 generation 과 다르면
		// status 가 아직 새 spec 을 반영하지 못한 것이다.
		site.Status.ObservedGeneration = site.Generation
		meta := metav1.Condition{
			Type:    "Available",
			Status:  condStatus,
			Reason:  reason,
			Message: fmt.Sprintf("%d/%d 준비됨", ready, site.Spec.Replicas),
		}
		setCondition(&site.Status.Conditions, meta)
		if err := r.Status().Update(ctx, &site); err != nil {
			return ctrl.Result{}, err
		}
	}

	return ctrl.Result{}, nil
}

func setCondition(conds *[]metav1.Condition, c metav1.Condition) {
	c.LastTransitionTime = metav1.Now()
	for i := range *conds {
		if (*conds)[i].Type == c.Type {
			if (*conds)[i].Status == c.Status {
				c.LastTransitionTime = (*conds)[i].LastTransitionTime
			}
			(*conds)[i] = c
			return
		}
	}
	*conds = append(*conds, c)
}

func (r *JournalSiteReconciler) desiredDeployment(site *studyv1alpha1.JournalSite) *appsv1.Deployment {
	labels := map[string]string{"app": site.Name, "managed-by": "journalsite-operator"}
	replicas := site.Spec.Replicas
	nonRoot := true
	var user int64 = 1000
	noEsc := false
	return &appsv1.Deployment{
		ObjectMeta: metav1.ObjectMeta{
			Name:      site.Name + "-api",
			Namespace: site.Namespace,
			Labels:    labels,
		},
		Spec: appsv1.DeploymentSpec{
			Replicas: &replicas,
			Selector: &metav1.LabelSelector{MatchLabels: map[string]string{"app": site.Name}},
			Template: corev1.PodTemplateSpec{
				ObjectMeta: metav1.ObjectMeta{Labels: labels},
				Spec: corev1.PodSpec{
					AutomountServiceAccountToken: new(bool),
					SecurityContext: &corev1.PodSecurityContext{
						RunAsNonRoot:   &nonRoot,
						RunAsUser:      &user,
						SeccompProfile: &corev1.SeccompProfile{Type: corev1.SeccompProfileTypeRuntimeDefault},
					},
					Containers: []corev1.Container{{
						Name:            "api",
						Image:           site.Spec.Image,
						ImagePullPolicy: corev1.PullIfNotPresent,
						Env:             []corev1.EnvVar{{Name: "LOG_LEVEL", Value: site.Spec.LogLevel}},
						Ports:           []corev1.ContainerPort{{Name: "http", ContainerPort: 8080}},
						Resources: corev1.ResourceRequirements{
							Requests: corev1.ResourceList{
								corev1.ResourceCPU:    resource.MustParse("20m"),
								corev1.ResourceMemory: resource.MustParse("48Mi"),
							},
							Limits: corev1.ResourceList{
								corev1.ResourceMemory: resource.MustParse("128Mi"),
							},
						},
						SecurityContext: &corev1.SecurityContext{
							AllowPrivilegeEscalation: &noEsc,
							Capabilities:             &corev1.Capabilities{Drop: []corev1.Capability{"ALL"}},
						},
						ReadinessProbe: &corev1.Probe{
							ProbeHandler: corev1.ProbeHandler{
								HTTPGet: &corev1.HTTPGetAction{Path: "/readyz", Port: intstr.FromString("http")},
							},
							PeriodSeconds: 2,
						},
					}},
				},
			},
		},
	}
}

func (r *JournalSiteReconciler) SetupWithManager(mgr ctrl.Manager) error {
	return ctrl.NewControllerManagedBy(mgr).
		For(&studyv1alpha1.JournalSite{}).
		// 우리가 만든 디플로이먼트가 바뀌어도 조정이 돈다.
		// 이것이 없으면 누가 디플로이먼트를 지워도 컨트롤러가 모른다.
		Owns(&appsv1.Deployment{}).
		Named("journalsite").
		Complete(r)
}
