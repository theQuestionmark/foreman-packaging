%{?scl:%scl_package nodejs-%{npm_name}}
%{!?scl:%global pkg_name %{name}}

%global npm_name bootstrap-select

Name: %{?scl_prefix}nodejs-bootstrap-select
Version: 1.13.18
Release: 1%{?dist}
Summary: Bootstrap-select is a jQuery plugin that utilizes Bootstrap's dropdown
License: MIT
Group: Development/Libraries
URL: https://developer.snapappointments.com/bootstrap-select
Source0: https://registry.npmjs.org/%{npm_name}/-/%{npm_name}-%{version}.tgz
%if 0%{?!scl:1}
BuildRequires: nodejs-packaging
%endif
Requires: %{?scl_prefix}npm(jquery) >= 1.9.1
Requires: %{?scl_prefix}npm(jquery) < 3
BuildArch: noarch
ExclusiveArch: %{nodejs_arches} noarch
Provides: %{?scl_prefix}npm(%{npm_name}) = %{version}

%description
%{summary}

%prep
%setup -q -n package

%install
mkdir -p %{buildroot}%{nodejs_sitelib}/%{npm_name}
cp -pfr dist %{buildroot}%{nodejs_sitelib}/%{npm_name}
cp -pfr js %{buildroot}%{nodejs_sitelib}/%{npm_name}
cp -pfr less %{buildroot}%{nodejs_sitelib}/%{npm_name}
cp -pfr nuget %{buildroot}%{nodejs_sitelib}/%{npm_name}
cp -pfr package.json %{buildroot}%{nodejs_sitelib}/%{npm_name}
cp -pfr sass %{buildroot}%{nodejs_sitelib}/%{npm_name}
cp -pfr tests %{buildroot}%{nodejs_sitelib}/%{npm_name}

%nodejs_symlink_deps

%check
%{nodejs_symlink_deps} --check

%files
%{nodejs_sitelib}/%{npm_name}
%license LICENSE
%doc CHANGELOG.md
%doc CONTRIBUTING.md
%doc README.md
%doc docs

%changelog
* Thu Sep 23 2021 Justin Sherrill <jsherril@redhat.com> 1.13.18-1
- Update to 1.13.18

* Wed Feb 24 2021 Ewoud Kohl van Wijngaarden <ewoud@kohlvanwijngaarden.nl> 1.13.6-1
- Update to 1.13.6

* Sun Oct 06 2019 Eric D. Helms <ericdhelms@gmail.com> - 1.12.4-2
- Update to handle building for SCL

* Thu Jun 07 2018 Eric D. Helms <ericdhelms@gmail.com> 1.12.4-1
- Update to 1.12.4

* Thu Apr 19 2018 Eric D. Helms <ericdhelms@gmail.com> 1.12.2-1
- Add nodejs-bootstrap-select generated by npm2rpm using the single strategy
