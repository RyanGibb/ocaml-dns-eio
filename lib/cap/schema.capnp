@0xf8f86fb5561e3599;

struct Prereq {
  name @0: Text;
  union {
    exists :group {
      type @1 :Int16;
    }
    existsData :group {
      type @2 :Int16;
      value @3 :Data;
    }
    notExists :group {
      type @4 :Int16;
    }
    nameInUse @5 :Void;
    notNameInUse @6 :Void;
  }
}

struct Update {
  name @0: Text;
  union {
    add :group {
      type @1 :Int16;
      value @2 :Data;
	  ttl @3 :Int32;
    }
    remove :group {
      type @4 :Int16;
    }
    removeAll @5 :Void;
    removeSingle :group {
      type @6 :Int16;
      value @7 :Data;
    }
  }
}

struct CertReq {
  # Used to request a certificate for a service
  union {
    callback @0 :CertCallback;
    none @1 :Void;
  }
}

interface Zone {
  # Capability to initialize a Zone for which the nameserver is authoritative
  init @0 (name :Text) -> (domain :Domain, primary :Primary);
}

interface Domain {
  # Capability for a domain

  getName @0 () -> (name :Text);
  # Get the domain name

  delegate @1 (subdomain :Text) -> (domain :Domain);
  # Create a capability for a subdomain

  update @2 (prereqs :List(Prereq), updates :List(Update)) -> (success :Bool, error :Text);
  # DNS update

  cert @3 (email: Text, domains :List(Text), org :Text, certCallback :CertCallback) -> ();
  # Request a certificate for a domain ("") / wildcard domain "*"
}

interface Primary {
  # Capability for a primary nameserver for a domain

  getName @0 () -> (name :Text);
  # Get the domain name that this primary is serving

  registerSeconday @1 (secondary :Secondary) -> ();
  # register a secondary server with this primary
  # as an optimisation we could add a serial number here
}

interface Secondary {
  # Capability for a secondary nameserver for a domain

  getName @0 () -> (name :Text);
  # Get the domain name that this secondary is serving

  update @1 (prereqs :List(Prereq), updates :List(Update)) -> (success :Bool, error :Text);
  # DNS update from primary
}

interface CertCallback {
  # Callback to support provisioning and renewal

  register @0 (success :Bool, error :Text, cert :Data, key :Text, renewed: Bool) -> ();
  # register a provisioned certificate
}

