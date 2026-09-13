/*
Copyright 2026.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package v1alpha1

import (
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
)

// EDIT THIS FILE!  THIS IS SCAFFOLDING FOR YOU TO OWN!
// NOTE: json tags are required.  Any new fields you add must have json tags for the fields to be serialized.

// JournalSiteSpec defines the desired state of JournalSite
type JournalSiteSpec struct {
	// 배포할 이미지. 태그를 반드시 붙이고 latest 는 쓸 수 없다.
	// +kubebuilder:validation:Pattern=`^[a-z0-9./-]+:[a-zA-Z0-9._-]+$`
	// 정규식으로는 "latest 가 아닐 것"을 쓰기 어렵다. CEL 로 쓴다 (M26 의 CEL 과 같은 언어다).
	// +kubebuilder:validation:XValidation:rule="!self.endsWith(':latest')",message="latest 태그는 쓸 수 없다"
	Image string `json:"image"`

	// 원하는 파드 수.
	// +kubebuilder:validation:Minimum=1
	// +kubebuilder:validation:Maximum=10
	// +kubebuilder:default=2
	Replicas int32 `json:"replicas,omitempty"`

	// +kubebuilder:validation:Enum=debug;info;warn;error
	// +kubebuilder:default=info
	LogLevel string `json:"logLevel,omitempty"`
}

// JournalSiteStatus defines the observed state of JournalSite.
type JournalSiteStatus struct {
	// 실제로 준비된 파드 수. 컨트롤러만 쓴다.
	ReadyReplicas int32 `json:"readyReplicas"`

	// Ready 또는 Progressing.
	Phase string `json:"phase,omitempty"`

	// 어느 세대의 spec 을 반영한 status 인지. 이것이 없으면
	// "낡은 status 를 보고 판단하는" 사고가 난다.
	ObservedGeneration int64 `json:"observedGeneration,omitempty"`

	// +listType=map
	// +listMapKey=type
	Conditions []metav1.Condition `json:"conditions,omitempty"`
}

// +kubebuilder:object:root=true
// +kubebuilder:subresource:status
// +kubebuilder:resource:shortName=js
// +kubebuilder:printcolumn:name="Replicas",type=integer,JSONPath=`.spec.replicas`
// +kubebuilder:printcolumn:name="Image",type=string,JSONPath=`.spec.image`
// +kubebuilder:printcolumn:name="Ready",type=integer,JSONPath=`.status.readyReplicas`
// +kubebuilder:printcolumn:name="Phase",type=string,JSONPath=`.status.phase`
// +kubebuilder:printcolumn:name="Age",type=date,JSONPath=`.metadata.creationTimestamp`

// JournalSite is the Schema for the journalsites API
type JournalSite struct {
	metav1.TypeMeta `json:",inline"`

	// metadata is a standard object metadata
	// +optional
	metav1.ObjectMeta `json:"metadata,omitzero"`

	// spec defines the desired state of JournalSite
	// +required
	Spec JournalSiteSpec `json:"spec"`

	// status defines the observed state of JournalSite
	// +optional
	Status JournalSiteStatus `json:"status,omitzero"`
}

// +kubebuilder:object:root=true

// JournalSiteList contains a list of JournalSite
type JournalSiteList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitzero"`
	Items           []JournalSite `json:"items"`
}

func init() {
	SchemeBuilder.Register(func(s *runtime.Scheme) error {
		s.AddKnownTypes(SchemeGroupVersion, &JournalSite{}, &JournalSiteList{})
		return nil
	})
}
