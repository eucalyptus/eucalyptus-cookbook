#!/bin/sh

if uname -r | grep -q el6; then
    CLASSPATH=$(build-classpath axis2 backport-util-concurrent commons-logging ws-commons-axiom ws-commons-XmlSchema ws-commons-neethi wsdl4j xalan-j2 xsltc) exec java org.apache.axis2.wsdl.WSDL2C $*
else
    CLASSPATH=$(build-classpath axiom axis2 commons-logging neethi wsdl4j xalan-j2 xalan-j2-serializer xalan-j2-xsltc XmlSchema) exec java org.apache.axis2.wsdl.WSDL2C $*
fi
